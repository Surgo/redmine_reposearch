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

class ReposearchController < ApplicationController
  unloadable
  layout 'base'
  menu_item :reposearch

  before_filter :find_project
  before_filter :authorize
  before_filter :open_db
  before_filter :parse_query
  before_filter :parse_target

  after_filter :close_db

  #rescue_from RedmineReposearch::EstraierError, :with => :estraier_command_failed


  def search
    unless @tokens.empty?
      @results = @db.search(@tokens, @target.identifier, @rev, nil, @all_words)
      @docs = []
      if @results
         @doc_pages = Paginator.new(self, @results.doc_num, per_page_option, params['page'])
         for i in @doc_pages.current.offset...
             [(@doc_pages.current.offset + @doc_pages.items_per_page), @results.doc_num].min
           @docs.push(@db.backend.get_doc(@results.get_doc(i).attr("@uri")))
         end
      end
    end
    render :layout => false if request.xhr?
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def open_db
    @db = RedmineReposearch::IndexDatabase.new(@project)
    (render_404; return false) if @db.repositories.size <= 0
    @db.open()
  end

  def close_db
    @db.close()
  end

  def parse_query
    def optimize_query(raw_query)
      raw_query.strip!
      raw_query = raw_query.gsub(/　/, " ").gsub(/,/, " ").gsub(/\s+/, " ")
      return raw_query
    end

    def generate_token(query)
      tokens = query.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {
        |m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
      tokens = tokens.uniq.select {|w| w.size > 1 }
      tokens.slice! 5..-1 if !tokens.empty? and tokens.size > 5
      return tokens
    end

    @query = optimize_query(params[:q] || "")
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @tokens = generate_token(@query)
    @query = "" if @tokens.empty?
  end

  def parse_target
    if params[:target].present?
      if params[:target] == RedmineReposearch::MAIN_REPOSITORY_IDENTIFIER
        @target = @project.repository
      else
        @target = @project.repositories.find_by_identifier_param(params[:target])
      end
    else
      @target = @project.repository
    end
    (render_404; return false) unless @target
    if (!@target.branches.nil? && @target.branches.size > 0) or (!@target.tags.nil? && @target.tags.size > 0)
      @rev = (params[:rev].blank? or not params[:rev].has_key?(@target.identifier)) ? \
        @target.default_branch : params[:rev][@target.identifier].to_s.strip
    else
      @rev = nil
    end
  end

  def estraier_command_failed(exception)
    @db.close()
  rescue RedmineReposearch::EstraierError => e
    logger.warn("Estraier close failed: %s" % e.message)
  ensure
    render_error l(:error_estraier_command_failed, exception.message)
    return false
  end
end
