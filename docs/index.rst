.. redmine_tweaks documentation master file, created by
   sphinx-quickstart on Sat Apr 23 16:31:21 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. _Redmine: https://www.redmine.org

Welcome to Redmine Tweaks Plugin
================================

Tweaks for wiki and content including new macros for `Redmine`_.


.. image:: https://gemnasium.com/alexandermeindl/redmine_tweaks.svg
   :target: https://gemnasium.com/alexandermeindl/redmine_tweaks

.. image:: https://drone.io/github.com/alexandermeindl/redmine_tweaks/status.png
   :target: https://drone.io/github.com/alexandermeindl/redmine_tweaks/latest


Requirements
------------

* Redmine version >= 2.6.0
* Ruby >= 2.0.0
* Gem package: see PluginGemfile


Installation
------------

Install redmine_tweaks

Check the requirements!

Download the sources and put them to your plugins folder.

.. code-block:: bash

  $ cd $REDMINE_ROOT
  $ git clone git://github.com/alexandermeindl/redmine_tweaks.git plugins/redmine_tweaks
  $ bundle install --without development test

More information about installation of Redmine plugins, you can find in the official `Redmine plugin documentation <https://www.redmine.org/projects/redmine/wiki/Plugins`_.

Features
--------

* use "Project guide" on project overview page
* global header for all projects
* global footer for all projects
* welcome text for login page
* global sidebar content support
* set info message above new ticket (e.g. for guidelines)
* Wiki user macros
* Wiki member macros
* Wiki project macros
* Wiki date macros
* Wiki Garfield marco
* Wiki Gist marco
* Wiki Youtube marco
* Wiki Vimeo marco
* option to remove "my page" from top menu
* customize "Help" url in top menu
* customize top menu items
* disable (hide) modules for projects
* open external urls in new window
* anonymize referrer for external urls
* Hide role in project memberbox
* Configurable issue rules

  * closing issue with open sub issues
  * change assigned_to automatically, if issue status changes
  * assigned_to has changed, but status change is required, too


Contacts and Support
--------------------

I will be glad to get your feedback, `pull requests <https://github.com/alexandermeindl/redmine_tweaks/pulls>`_, `issues <https://github.com/alexandermeindl/redmine_tweaks/issues>`_, whatever. Feel free to contact me for any questions.


Table of contents
-----------------

.. toctree::
    :maxdepth: 2

    manual
    macros
    changelog