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

require "estraier"
include Estraier
include ActionController::UrlWriter

module ReposearchEngine
  FILE_MAX_SIZE = Setting.file_max_size_displayed.to_i.kilobyte
  DATABASE_ROOT = ENV['RAILS_VAR'] ?
    File.join(ENV['RAILS_VAR'], 'reposearch') :
    File.join(Rails.root, 'reposearch')

  MODE_W = Estraier::Database::DBWRITER | Estraier::Database::DBCREAT
  MODE_R = Estraier::Database::DBREADER

  STATUS_SUCCESS = 1
  STATUS_FAILED = 0
  STATUS_REMOVED = -1

  ADD_OR_UPDATE = 1
  DELETE = 0

  class EstraierError < StandardError; end

  class IndexDatabase
    attr_accessor :project, :name, :repository, :latest_changeset, :latest_log, :path, :latest_status, :est_db

    def initialize(project)
      @project = project
      @name = @project.name
      @repository = @project.repository
      @path = File.join(DATABASE_ROOT, @project.identifier)

      @latest_changeset = @repository.changesets.find(:first)
      @latest_log = Indexinglog.find_by_repository_id_and_status(@repository.id, STATUS_SUCCESS)

      @current_log = nil
      @est_db = nil
      @latest_status = nil
    end

    def is_open?
      return true if @est_db
      return false
    end

    def open(mode=MODE_R)
      @latest_status = nil
      FileUtils.mkdir_p(@path) unless File.exist?(@path)
      if !is_open?
        @est_db = Database::new
        RAILS_DEFAULT_LOGGER.info("Open DB: %s" % @path)
        unless @est_db.open(@path, mode)
          @latest_status = @est_db.err_msg(@est_db.error)
          @est_db = nil
          raise EstraierError.new("Open failed - '%s'" % @latest_status)
        end
      end
    end

    def close
      @latest_status = nil
      if is_open?
        RAILS_DEFAULT_LOGGER.info("Close DB: %s" % @path)
        unless @est_db.close()
          @latest_status = @est_db.err_msg(@est_db.error)
          @est_db = nil
          raise EstraierError.new("Close failed - '%s'" % @latest_status)
        end
      end
      @est_db = nil
    end

    def remove
      RAILS_DEFAULT_LOGGER.info("Remove DB: %s" % @path)
      close()
      FileUtils.rm_r(Dir.glob(File.join(@path, '*')), {:force=>true})
      Indexinglog.update_all("status = #{STATUS_REMOVED}", {:repository_id => @repository.id, })
    end

    def indexing(init=false)
      @latest_status = nil

      raise EstraierError.new("Changeset not found.") unless @latest_changeset

      @current_log = Indexinglog.new
      @current_log.repository = @repository
      @current_log.changeset = @latest_changeset
      @current_log.save!

      @current_log.status = STATUS_SUCCESS
      if init or not @latest_log
        indexing_all()
      else
        indexing_diff()
      end
      @current_log.save!

      raise EstraierError.new("Indexing failed: %s" % @latest_status) if @latest_status
    end

    def optimize
      raise EstraierError.new("Optimize failed: %s" % @est_db.err_msg(@est_db.error)) unless @est_db.optimize(0)
    end

    private

    def indexing_all
      def walk(entries)
        return if entries.size < 1
        entries.each do |entry|
          if entry.is_dir?
            walk(@repository.entries(entry.path))
          elsif entry.is_file?
            add_or_update_index(entry.path)
          end
        end
      end

      RAILS_DEFAULT_LOGGER.info("Indexing all: %s" % @repository.url)
      @current_log.message = "Success - all"
      walk(@repository.entries())
    end

    def indexing_diff
      RAILS_DEFAULT_LOGGER.info("Indexing diff: %s" % @repository.url)
      @current_log.message = "Success - diff"
      if @latest_log.changeset_id >= @latest_changeset.id
        @current_log.message = "Already indexed: %d" % @latest_changeset.id
        return
      end

      RAILS_DEFAULT_LOGGER.info("Diff with: %d and %d" % [@latest_log.changeset_id, @latest_changeset.id, ])
      changesets = project.repository.changesets.find(
        :all, :conditions => {:id => @latest_log.changeset_id..@latest_changeset.id, },
        :order => "id ASC")
      unless changesets
        @current_log.status = STATUS_FAILED
        @latest_status = @current_log.message = "Cannot get changesets"
        return false
      end

      actions = Hash::new
      changesets.each do |changeset|
        next unless changeset.changes
        RAILS_DEFAULT_LOGGER.debug("Check changesets: %d" % changeset.id)
        changeset.changes.each do |change|
          if change.action == 'D'
            actions[change.path] = DELETE
          else
            actions[change.path] = ADD_OR_UPDATE
          end
        end
      end
      actions.each do |path, action|
        if action == ADD_OR_UPDATE
          add_or_update_index(path)
        else
          delete_index(path)
        end
      end
    end

    def add_or_update_index(path)
      RAILS_DEFAULT_LOGGER.debug("Add / Update: %s" % path)
      uri = url_for(:controller => 'repositories',
                    :action => 'entry',
                    :id => @project,
                    :path => @repository.relative_path(path),
                    :only_path => true)
      return unless uri
      content = @repository.cat(path)
      mimetype = Redmine::MimeType.of(path)
      put_document(uri, path, content, mimetype)
    end

    def delete_index(path)
      RAILS_DEFAULT_LOGGER.debug("Delete: %s" % path)
      uri = url_for(:controller => 'repositories',
                    :action => 'entry',
                    :id => @project,
                    :path => @repository.relative_path(path),
                    :only_path => true)
      return unless uri
      put_document(uri, "", "", "")
    end

    def put_document(uri, title, text, type=nil)
      doc = Estraier::Document::new
      doc.add_attr('@uri', uri)
      doc.add_attr('@title', title)
      doc.add_text(text)
      doc.add_attr('@type', type) if type
      unless @est_db.put_doc(doc, Estraier::Database::PDCLEAN)
        RAILS_DEFAULT_LOGGER.warn("Document put failed - %s" % @est_db.err_msg(@est_db.error))
        @current_log.status = STATUS_FAILED
        @latest_status = @current_log.message = "Document put failed - %s" % @est_db.err_msg(@est_db.error)
      end
    end
  end

  def self.is_accessible(project)
    return project.repository &&
      (project.is_public? || User.current.member_of?(project) || User.current.admin?)
  end

  def self.get_all_projects
    return Project.active.has_module(:repository).find(:all, :include => :repository)
  end

  def self.get_accessible_projects
    return self.get_all_projects().select{|project| self.is_accessible(project)}
  end

  def self.get_my_projects
    return User.current.memberships.collect(&:project).compact.uniq
  end

  def self.open_dbs(dbs, mode=MODE_R)
    if dbs and dbs.any?
      dbs.each do |db|
        db.open(mode)
      end
    end
  end

  def self.close_dbs(dbs)
    if dbs and dbs.any?
      dbs.each do |db|
        db.close()
      end
    end
  end

  def self.search(dbs, tokens, all_words=true, type=nil)
    return [] unless tokens
    est_dbs = dbs.each.map{|db| db.est_db}
    condition = Estraier::Condition::new
    if all_words
      phrase = tokens.join(" AND ")
    else
      phrase = tokens.join(" OR ")
    end
    condition.set_phrase(phrase)
    condition.add_attr("@type EQ %s" % type) if type
    RAILS_DEFAULT_LOGGER.debug("Search phrase: %s" % phrase)
    return Estraier::Database::search_meta(dbs.each.map{|db| db.est_db}, condition)
  end
end
