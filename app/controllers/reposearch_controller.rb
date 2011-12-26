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

  before_filter :find_optional_project
  before_filter :find_projects
  before_filter :parse_queries
  before_filter :open_dbs
  after_filter :close_dbs

  rescue_from ReposearchEngine::EstraierError, :with => :estraier_command_failed


  def search
    if !@tokens.empty?
      @results = ReposearchEngine.search(@dbs, @tokens)
      @docs = Hash.new
      if @results
         @doc_pages = Paginator.new self, @results.doc_num, per_page_option, params['page']
         for i in @doc_pages.current.offset...
             [(@doc_pages.current.offset + @doc_pages.items_per_page), @results.doc_num].min
           dbidx = @results.get_dbidx(i)
           next unless dbidx
           doc = @dbs[dbidx].est_db.get_doc(@results.get_doc_id(i), 0)
           next unless doc
           @docs[doc] = @dbs[dbidx].project
         end
      end
    end
    render :layout => false if request.xhr?
  end

  private

  def find_optional_project
    return true unless params[:id]
    @project = Project.active.find(params[:id])
    check_project_privacy
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_projects
    @projects =
      case params[:scope]
      when 'all'
        ReposearchEngine.get_accessible_projects()
      when 'my_projects'
        ReposearchEngine.get_my_projects()
      when 'subprojects'
        @project ?
          @project.self_and_descendants.active.has_module(:repository).
            select{|project| ReposearchEngine.is_accessible(project)}:
          ReposearchEngine.get_accessible_projects()
      else
        @project ?
          [@project, ] :
          ReposearchEngine.get_accessible_projects()
      end
    unless @projects
      render_404
    end
  end

  def parse_queries
    @query = params[:q] || ""
    @query.strip!
    @query = @query.gsub(/　/, " ").gsub(/,/, " ").gsub(/\v/, " ")
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @tokens = @query.scan(%r{((\s|^)"[\s\w]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
    @tokens = @tokens.uniq.select {|w| w.length > 1 }
    if !@tokens.empty?
      @tokens.slice! 5..-1 if @tokens.size > 5
    else
      @query = ""
    end
    @docs = []
  end

  def open_dbs
    @dbs = []
    @projects.each do |project|
      next unless project.repository
      db = ReposearchEngine::IndexDatabase.new(project)
      next unless db.latest_log
      @dbs.push(db)
    end
    render_404 unless @dbs
    ReposearchEngine.open_dbs(@dbs)
  end

  def close_dbs
    ReposearchEngine.close_dbs(@dbs)
  end

  def estraier_command_failed(exception)
    ReposearchEngine.close_dbs(@dbs)
    logger.error("Estraier command failed: %s" % exception.message)
    render_error l(:error_estraier_command_failed, exception.message)
    return false
  rescue ActionController::DoubleRenderError
    render_error l(:error_estraier_command_failed, exception.message)
    return false
  end
end
