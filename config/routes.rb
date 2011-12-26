ActionController::Routing::Routes.draw do |map|
  map.with_options :controller => 'reposearch' do |reposearch|
    reposearch.connect 'projects/:id/reposearch', :action => 'search'
    reposearch.connect 'reposearch', :action => 'search'
  end
  map.with_options :controller => 'repoindexer' do |repoindexer|
    repoindexer.connect 'repoindexer/init/:id', :action => 'indexing', :init => true
    repoindexer.connect 'repoindexer/crawl/:id', :action => 'indexing', :init => false
  end
end
