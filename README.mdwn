# Overview

The Expired Entries plugin for Movable Type and Melody allows 
authors to select a date in the future at which an entry will 
be automatically unpublished and the site rebuilt.

# Why unpublish something?

For a blog, unpublishing is sacriledge, but not everyone uses
Movable Type to power a blog. Some people administer store fronts 
powered by Movable Type in which items are seasonal, or for which
a vendor is only allowed to sell an item for certain period of time.
Some people may want to orchestrate by automating the deployment of 
new web site content - in which they used scheduled posts and post
expiration to remove outdated copy and publish new copy all at once.
The truth is there are tons of reasons you might want automatically
remove something from a web site.

# Prerequisities

* Movable Type 4.x.
* Your site must be running the `tools/run-periodic-tasks` script
  as a cronjob or in daemon mode.

# Installation

To install this plugin follow the instructions found here:

http://tinyurl.com/easy-plugin-install

# Usage

Once the plugin is installed a new option will appear on the Edit Entry 
screen under each entry and page's publish date field.
Select a date, save the entry and done.

At the appointed time the entry's status will be changed to 
"Unpublished (Expired)," the entry will be removed from the web site
and the necessary pages in your web site rebuilt to remove all 
trace of the entry or page.

# Config Directives

* **ExpireEntryFrequency** - The amount of time in minutes to 
wait before checking, expiring and unpublishing entries. The default 
is 1 (expressed in minutes).