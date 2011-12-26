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

class RepoindexerController < ActionController::Base
  unloadable

  before_filter :check_enabled
  before_filter :find_project
  before_filter :open_db
  after_filter :close_db

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :scm_command_failed
  rescue_from ReposearchEngine::EstraierError, :with => :estraier_command_failed


  def indexing
    logger.debug("Indexing: %s" % @db.name)
    @db.indexing(params[:init])
    @db.optimize()
    logger.info("Successfully indexed %s: %d docs" % [@db.name, @db.est_db.doc_num()])
    render :text => 'Successfully indexed!', :status => 200
  end

  private

  def find_project
    @project = Project.active.has_module(:reposearch).find(params[:id])
    unless @project.repository
      render :text => 'Project has not repository.', :status => 404
      return false
    end
    unless @project.repository.supports_cat?
      render :text => 'Unsupported repository.', :status => 404
      return false
    end
    @project.repository.fetch_changesets
  rescue ActiveRecord::RecordNotFound
    render :text => 'Project not found.', :status => 404
    return false
  end

  def open_db
    @db = ReposearchEngine::IndexDatabase.new @project
    @db.remove() if params[:init]
    @db.open(ReposearchEngine::MODE_W)
  end

  def close_db
    @db.close()
  end

  def scm_command_failed(exception)
    @db.close()
    logger.error("SCM command failed: " % exception.message)
    render :text => "SCM command failed: " % exception.message, :status => 500
    return false
  end

  def estraier_command_failed(exception)
    @db.close()
    logger.error("Estraier command failed: " % exception.message)
    render :text => "Estraier command failed: " % exception.message, :status => 500
    return false
  rescue ActionController::DoubleRenderError
    render :text => "Estraier command failed: " % exception.message, :status => 500
    return false
  end

  def check_enabled
    User.current = nil
    unless Setting.sys_api_enabled? && params[:key].to_s == Setting.sys_api_key
      render :text => 'Access denied. Repository management WS is disabled or key is invalid.', :status => 403
      return false
    end
  end
end
