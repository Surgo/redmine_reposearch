Redmine reposearch plugin
=========================

Add full-text search engine to repositories.

Authors
-------

 * [Kosei Kitahara](http://surgo.jp/) ([@Surgo](http://twitter.com/Surgo))

Requirements
------------

* [Redmine 1.1](http://www.redmine.org/)
* [Hyper Estraier](http://fallabs.com/hyperestraier/index.html)
* [Ruby Binding of Hyper Estraier](http://fallabs.com/hyperestraier/rubynativeapi/)

Special Thanks to [Redmine](http://www.redmine.org/) and [FAL Labs](http://fallabs.com/)

Install
-------

For Ubuntu.

1. Install Hyper Estraier / Ruby Binding
       sudo apt-get install hyperestraier libestraier-ruby`
2. [Install plugin to redmine](http://www.redmine.org/projects/redmine/wiki/Plugins)

That's all!

Pages and Commands
------------------

### Pages (for users) ###

* http://redmine.site/[project]/reposearch -- Search codes in project's / sub-project's accessiable repositories.
* http://redmine.site/reposearch -- Search codes in all accessiable repositories.

### Commands (for SCM) ###

* http://redmine.site/repoindexer/init/[project] -- Create / Re-create project's indexes.
* http://redmine.site/repoindexer/crawl/[project] -- Crawl project's indexes (if updated).

Replace SCM commit hooks to "Crawl project's indexes".

Links
-----

 * [Project page](http://surgo.github.com/redmine_reposearch/)
 * [Issues](https://github.com/Surgo/redmine_reposearch/issues)
 * [Source code](https://github.com/Surgo/redmine_reposearch)
 * [Documents](https://github.com/Surgo/redmine_reposearch/wiki)
