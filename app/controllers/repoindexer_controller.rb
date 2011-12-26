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
