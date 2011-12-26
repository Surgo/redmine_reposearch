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

class RepoindexerController < ApplicationController
  unloadable

  before_filter :find_project_to_crawl
  before_filter :open_db
  after_filter :close_db

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :scm_command_failed
  rescue_from ReposearchEngine::EstraierError, :with => :estraier_command_failed


  def indexing
    if @db.repository and @db.repository.supports_cat?
      logger.debug("Indexing: %s" % @db.name)
      @db.indexing(params[:init])
      @db.optimize()
      logger.info("Successfully indexed %s: %d docs" % [@db.name, @db.est_db.doc_num()])
      render :nothing => true, :status => 200
    else
      logger.warn("Skip indexing (unsupported): %s" % project.name)
      render :nothing => true, :status => 404
    end
  end

  private

  def find_project_to_crawl
    @project = Project.active.has_module(:reposearch).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render :nothing => true, :status => 404
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
    render :nothing => true, :status => 500
    return false
  end

  def estraier_command_failed(exception)
    @db.close()
    logger.error("Estraier command failed: " % exception.message)
    render :nothing => true, :status => 500
    return false
  rescue ActionController::DoubleRenderError
    render :nothing => true, :status => 500
    return false
  end
end
