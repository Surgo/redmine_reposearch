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

class RepoindexerController < SysController
  unloadable

  before_filter :check_enabled
  before_filter :find_project
  before_filter :open_db
  after_filter :close_db

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :scm_command_failed
  rescue_from RedmineReposearch::EstraierError, :with => :estraier_command_failed


  def indexing
    logger.info("Indexing: %s" % @project.name)
    @db.indexing()
    @db.optimize()
    logger.info("Successfully indexed %s: %d docs" % [@project.name, @db.est_db.doc_num()])
    render :text => 'Successfully indexed!', :status => 200
  end

  private

  def find_project
    scope = Project.active.has_module(:repository)
    @project = nil
    if params[:id].to_s =~ /^\d*$/
      @project = scope.find(params[:id])
    else
      @project = scope.find_by_identifier(params[:id])
    end
    raise ActiveRecord::RecordNotFound unless @project
  rescue ActiveRecord::RecordNotFound
    render :text => 'Project not found.', :status => 404
    return false
  end

  def open_db
    @db = RedmineReposearch::IndexDatabase.new(@project)
    @db.remove() if params[:init]
    if @db.repositories.size <= 0
      render :text => 'Project has not (supported) repository.', :status => 404
      return false
    end
    @db.open(RedmineReposearch::MODE_W)
  end

  def close_db
    @db.close()
  end

  def handle_error(err_msg)
    @db.close()
  rescue RedmineReposearch::EstraierError => e
    logger.warn("Estraier close failed: %s" % e.message)
  ensure
    logger.error(err_msg)
    render :text => err_msg, :status => 500
    return false
  end

  def scm_command_failed(exception)
    return handle_error("SCM command failed: %s" % exception.message)
  end

  def estraier_command_failed(exception)
    return handle_error("EstraierError command failed: %s" % exception.message)
  end
end
