# encoding: utf-8
# frozen_string_literal: true
#
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

module RedmineCustomWorkflows
  module Patches
    module IssueRelationPatch

      def self.prepended(base)
        base.class_eval do
          before_save :before_save_custom_workflows
          after_save :after_save_custom_workflows
          before_destroy :before_destroy_custom_workflows
          after_destroy :after_destroy_custom_workflows

          # override IssueRelation.to_s to rescue NoMethodError during CustomWorkflow.validate_syntax due to
          # logging of temporarily instatiated IssueRelation with no related issues set
          alias_method :old_to_s, :to_s
    
          def to_s(issue=nil)
            if block_given?
              if Gem.ruby_version < Gem::Version.new('3.0')
                old_to_s issue, &Proc.new
              else
                old_to_s issue, &Proc.new {}
              end
            else
              old_to_s issue
            end
          rescue NoMethodError => e
            if issue_from.present? || issue_to.present?
              raise e
            end
            self.class.to_s
          end
        end
      end

      def before_save_custom_workflows
        @issue_relation = self
        @saved_attributes = attributes.dup
        CustomWorkflow.run_shared_code self
        CustomWorkflow.run_custom_workflows :issue_relation, self, :before_save
        throw :abort if errors.any?
        errors.empty? && (@saved_attributes == attributes || valid?)
      ensure
        @saved_attributes = nil
      end

      def after_save_custom_workflows
        CustomWorkflow.run_custom_workflows :issue_relation, self, :after_save
      end

      def before_destroy_custom_workflows
        CustomWorkflow.run_custom_workflows :issue_relation, self, :before_destroy
      end

      def after_destroy_custom_workflows
        CustomWorkflow.run_custom_workflows :issue_relation, self, :after_destroy
      end

    end
  end
end
  
# Apply the patch
if Redmine::Plugin.installed?(:easy_extensions)
  RedmineExtensions::PatchManager.register_model_patch 'IssueRelation', 'RedmineCustomWorkflows::Patches::IssueRelationPatch'
else
  IssueRelation.prepend RedmineCustomWorkflows::Patches::IssueRelationPatch
end
