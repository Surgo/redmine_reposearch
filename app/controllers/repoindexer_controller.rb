class RepoindexerController < ApplicationController
  unloadable

  before_filter :find_projects
  before_filter :open_dbs
  after_filter :close_dbs

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :scm_command_failed
  rescue_from ReposearchEngine::EstraierError, :with => :estraier_command_failed


  def indexing
    status = 200
    @dbs.each do |db|
      if db.repository and db.repository.supports_cat?
        logger.debug("Indexing: %s" % db.name)
        unless db.indexing(params[:init])
          logger.warn("Failed indexing %s: %s" % [db.name, db.latest_status, ])
          status = 500
        else
          logger.info("Successfully: %s" % db.name)
          db.optimize()
          logger.info("Doc nums: %d" % db.est_db.doc_num())
        end
      else
        logger.warn("Skip indexing (unsupported): %s" % project.name)
      end
    end
    render :nothing => true, :status => status
  end

  private

  def find_projects
    unless params[:id]
      @projects = ReposearchEngine.get_all_projects()
    else
      begin
        @projects = [Project.active.has_module(:repository).find(params[:id]), ]
      rescue ActiveRecord::RecordNotFound
        render :nothing => true, :status => 404
        return false
      end
    end
    if not @projects or @projects.empty?
      render :nothing => true, :status => 404
      return false
    end
  end

  def open_dbs
    @dbs = []
    @projects.each do |project|
      db = ReposearchEngine::IndexDatabase.new project
      @dbs.push(db)
    end
    if not @dbs or @dbs.empty?
      render :nothing => true, :status => 404
      return false
    end
    if params[:init]
      @dbs.each do |db|
        logger.info("Remove database: %s" % db.path)
        db.remove()
      end
    end
    ReposearchEngine.open_dbs(@dbs, ReposearchEngine::MODE_W)
  end

  def close_dbs
    ReposearchEngine.close_dbs(@dbs)
  end

  def scm_command_failed(exception)
    ReposearchEngine.close_dbs(@dbs)
    logger.error("SCM command failed: " % exception.message)
    render :nothing => true, :status => 500
    return false
  end

  def estraier_command_failed(exception)
    ReposearchEngine.close_dbs(@dbs)
    logger.error("Estraier command failed: " % exception.message)
    render :nothing => true, :status => 500
    return false
  rescue ActionController::DoubleRenderError
    render :nothing => true, :status => 500
    return false
  end
end
