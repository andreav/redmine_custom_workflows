#!/bin/bash
# Redmine plugin for Custom Workflows
#
# Copyright © 2015-19 Anton Argirov
# Copyright © 2019-22 Karel Pičman <karel.picman@kontron.com>
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
#
# The script for GitLab Continuous Integration

# Exit if any command fails
set -e

# Display the first argument (DB engine)
echo $1

# Variables
REDMINE_REPO=http://svn.redmine.org/redmine/branches/4.2-stable/
REDMINE_PATH=/opt/redmine

# Init
rm -rf "${REDMINE_PATH}"

# Clone Redmine
svn export "${REDMINE_REPO}" "${REDMINE_PATH}"

# Add the plugin
ln -s /app "${REDMINE_PATH}"/plugins/redmine_custom_workflows

# Prepare the database
cp "./test/ci/$1.yml" "${REDMINE_PATH}/config/database.yml"
case $1 in

  mariadb)
    /etc/init.d/$1 start
    mariadb -e "CREATE DATABASE IF NOT EXISTS test CHARACTER SET utf8mb4"
    mariadb -e "CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'redmine'";
    mariadb -e "GRANT ALL PRIVILEGES ON test.* TO 'redmine'@'localhost'";
    ;;

  postgres)
    /etc/init.d/$1ql start
    su -c "psql -c \"CREATE ROLE redmine LOGIN ENCRYPTED PASSWORD 'redmine' NOINHERIT VALID UNTIL 'infinity';\"" postgres
    su -c "psql -c \"CREATE DATABASE test WITH ENCODING='UTF8' OWNER=redmine;\"" postgres
    su -c "psql -c \"ALTER USER redmine CREATEDB;\"" postgres
    ;;

  sqlite3)
    ;;

  *)
    echo 'Missing argument'
    exit 1
    ;;
esac

# Install Redmine
cd "${REDMINE_PATH}"
gem install bundler
RAILS_ENV=test bundle config set --local without 'development'
RAILS_ENV=test bundle install
RAILS_ENV=test bundle exec rake generate_secret_token
RAILS_ENV=test bundle exec rake db:migrate
RAILS_ENV=test bundle exec rake redmine:plugins:migrate
RAILS_ENV=test REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Run Redmine tests
#RAILS_ENV=test bundle exec rake test

# Run Custom Workflows' tests
bundle exec rake redmine:plugins:test:units NAME=redmine_custom_workflows RAILS_ENV=test
bundle exec rake redmine:plugins:test:functionals NAME=redmine_custom_workflows RAILS_ENV=test
bundle exec rake redmine:plugins:test:integration NAME=redmine_custom_workflows RAILS_ENV=test

# Clean up database from the plugin changes
bundle exec rake redmine:plugins:migrate NAME=redmine_custom_workflows VERSION=0 RAILS_ENV=test

case $1 in

  mariadb)
    /etc/init.d/$1 stop
    ;;

  postgres)
    /etc/init.d/$1ql stop
    ;;

  sqlite3)
    ;;

  *)
    echo 'Missing argument'
    exit 1
    ;;
esac

echo "$1 Okay"
