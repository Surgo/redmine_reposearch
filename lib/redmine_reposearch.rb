#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Redmine reposearch plugin
# Copyright (C) Kosei Kitahara.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

include Rails.application.routes.url_helpers
require "redmine_reposearch_pure_estraier"

module RedmineReposearch
  FILE_MAX_SIZE = Setting.file_max_size_displayed.to_i.kilobyte

  MODE_W = "MODE_W"
  MODE_R = "MODE_R"

  STATUS_SUCCESS = 1
  STATUS_FAIL = -1

  ADD_OR_UPDATE = 1
  DELETE = 0

  MAIN_REPOSITORY_IDENTIFIER = '[main]'

  INDEXED_FILES = ["java", "xml", "properties","feature", "html", "html", "xhtml", "css", "js", "txt","sh", "cmd","bat" , "rb", "yml", "erb"]

  class IndexingError < StandardError; end

  class IndexDatabase
    attr_accessor :backend, :project, :repository, :repositories, :latest_changeset, :latest_log

    def initialize(project)
      @project = project
      if @repository.respond_to?(:repositories)
        @repositories = @project.repositories.select { |repository| repository.supports_cat? }
      else
        @repositories = [@project.repositories]
      end
      @repositories = @repositories[0].select { |repository| repository.supports_cat? }
      @backend = nil
    end

    def search(tokens, repository, rev, content_type=nil, all_words=true)
      return [] unless tokens

      if all_words
        phrase = tokens.join(" AND ")
      else
        phrase = tokens.join(" OR ")
      end
      Rails.logger.info("Search phrase: %s" % phrase)
      Rails.logger.info("Search conditions: %s, %s, %s" % [
          repository, rev, content_type])
      return @backend.search(phrase,repository,rev,content_type)
    end

    def is_open?
      return true
    end

    def open(mode=MODE_R)
      @backend = RedmineReposearchPureEstraier::RedmineReposearchPureEstraierBackend.new
      @backend.open(mode)
    end

    def close
      if is_open?
        Rails.logger.debug("Close DB for project : %s ." % @project.name)
        @backend.close
      end
      @backend = nil
    end

    def remove
      @repositories.each do |repository|
        Rails.logger.info("Remove logs: %s - %s" % [
                          @project.name,
                          (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
        Indexinglog.delete_all(['repository_id = ?', repository.id])
      end
      @backend.remove
    end

    def optimize
      Rails.logger.debug("Optimize DB: %s" % @path)
      @backend.optimize
    end

    def indexing
      @repositories.each do |repository|
        Rails.logger.info("Fetch changesets: %s - %s" % [
                          @project.name,
                          (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
        repository.fetch_changesets
        repository.reload.changesets.reload

        latest_changeset = repository.changesets.find(:first)
        next if not latest_changeset

        Rails.logger.debug("Latest revision: %s - %s - %s" % [
                           @project.name,
                           (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
                           latest_changeset.revision])
        latest_indexed = Indexinglog.find_by_repository_id_and_status(
          repository.id, STATUS_SUCCESS, :first)
        begin
          if not latest_indexed
            indexing_all(repository)
          else
            indexing_diff(repository, latest_indexed.changeset, latest_changeset)
          end
        rescue IndexingError => e
          add_log(repository, latest_changeset, STATUS_FAIL, e.message)
        else
          add_log(repository, latest_changeset, STATUS_SUCCESS)
          Rails.logger.info("Successfully indexed: %s - %s - %s" % [
                            @project.name,
                            (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
                            latest_changeset.revision])
        end
      end
    end

    private

    def index_entry?(repository, path)
      path = repository.relative_path(path)
      path_parts = path.split "/"
      path_parts.each { |part| return false if part.start_with? "." }
      last_part = path_parts.last
      last_part_extension = last_part[/^.+\.(.+?)$/,1]
      return INDEXED_FILES.include? last_part_extension
    end

    def add_log(repository, changeset, status, message=nil)
      log = Indexinglog.new
      log.repository = repository
      log.changeset = changeset
      log.status = status
      log.message = message if message
      log.save!
    end

    def indexing_all(repository)
      def walk(repository, identifier, entries)
        return if entries.size < 1
        entries.each do |entry|
          if entry.is_dir?
            walk(repository, identifier, repository.entries(entry.path, identifier))
          elsif entry.is_file?
            add_or_update_index(repository, identifier, entry)
          end
        end
      end

      Rails.logger.info("Indexing all: %s" % [
                        (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
      if repository.branches
        repository.branches.each do |branch|
          Rails.logger.debug("Walking in branch: %s - %s" % [
                             (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), branch])
          walk(repository, branch, repository.entries(nil, branch))
        end
      else
        Rails.logger.debug("Walking in branch: %s - %s" % [
                           (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), "[NOBRANCH]"])
        walk(repository, nil, repository.entries(nil, nil))
      end
      #if repository.tags
      #  repository.tags.each do |tag|
      #    Rails.logger.debug("Walking in tag: %s - %s" % [
      #                       (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), tag])
      #    walk(repository, tag, repository.entries(nil, tag))
      #  end
      #end
    end

    def indexing_diff(repository, diff_from, diff_to)
      def walk(repository, identifier, changesets)
        return if not changesets or changesets.size <= 0
        changesets.sort! { |a, b| a.id <=> b.id }

        actions = Hash::new
        # SCM actions
        #   * A - Add
        #   * M - Modified
        #   * R - Replaced
        #   * D - Deleted
        changesets.each do |changeset|
          next unless changeset.changes
          changeset.changes.each do |change|
            if change.action == 'D'
              actions[change.path] = DELETE
            else
              actions[change.path] = ADD_OR_UPDATE
            end
          end
        end
        return unless actions
        actions.each do |path, action|
          entry = repository.entry(path, identifier)
          if action == DELETE
            delete_doc(repository, identifier, path)
          else
            add_or_update_index(repository, identifier, entry)
          end
        end
      end

      if diff_from.id >= diff_to.id
        Rails.logger.info("Already indexed: %s (from: %s to %s)" % [
                          (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
                          diff_from.id, diff_to.id])
        return
      end

      Rails.logger.info("Indexing diff: %s (from: %s to %s)" % [
                        (repository.identifier or MAIN_REPOSITORY_IDENTIFIER),
                        diff_from.id, diff_to.id])

      Rails.logger.info("Indexing all: %s" % [
                        (repository.identifier or MAIN_REPOSITORY_IDENTIFIER)])
      if repository.branches
        repository.branches.each do |branch|
          Rails.logger.debug("Walking in branch: %s - %s" % [
                             (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), branch])
          walk(repository, branch,
               repository.latest_changesets("", branch, diff_to.id - diff_from.id)\
               .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})

        end
      else
        Rails.logger.debug("Walking in branch: %s - %s" % [
                           (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), "[NOBRANCH]"])
        walk(repository, nil,
             repository.latest_changesets("", nil, diff_to.id - diff_from.id)\
             .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
      end
      #if repository.tags
      #  repository.tags.each do |tag|
      #    Rails.logger.debug("Walking in tag: %s - %s" % [
      #                       (repository.identifier or MAIN_REPOSITORY_IDENTIFIER), tag])
      #    walk(repository, tag,
      #         repository.latest_changesets("", tag, diff_to.id - diff_from.id)\
      #         .select { |changeset| changeset.id > diff_from.id and changeset.id <= diff_to.id})
      #  end
      #end
    end

    def generate_uri(repository, identifier, path)
      return url_for(:controller => 'repositories',
                    :action => 'entry',
                    :id => @project,
                    :repository_id => repository.identifier,
                    :rev => identifier,
                    :path => repository.relative_path(path),
                    :only_path => true)
    end

    def add_or_update_index(repository, identifier, entry)
      uri = generate_uri(repository, identifier, entry.path)
      return unless uri
      if not index_entry?(repository,entry.path)
        Rails.logger.info("Skipping : %s" % uri)
        return
      end
      Rails.logger.info("Add or update doc: %s" % uri)
      @backend.add_or_update_index(repository,identifier,entry,uri)
    end

    def delete_doc(repository, identifier, path)
      uri = generate_uri(repository, identifier, path)
      if not index_entry?(repository,entry.path)
        Rails.logger.info("Skipping : %s" % uri)
        return
      end
      Rails.logger.info("Delete doc: %s" % uri)
      @backend.delete_doc(uri)
    end
  end

  class RedmineRepoSearchBackend

    def open(mode)

    end

    def close

    end

    def remove

    end

    def delete_doc(uri)
      return nil
    end

    def add_or_update_index(repository, identifier, entry, uri)
      return nil
    end

    def optimize
      return nil
    end

    def search(query, repository, rev, content_type=nil)
      return nil
    end
  end
end
