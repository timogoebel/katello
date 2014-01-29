#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'katello_test_helper'

module Katello
class ContentViewTest < ActiveSupport::TestCase

  def self.before_suite
    models = ["Organization", "KTEnvironment", "User", "ContentViewEnvironment",
              "Repository", "ContentView", "ContentViewVersion",
              "ComponentContentView", "System"]
    services = ["Candlepin", "Pulp", "ElasticSearch"]
    disable_glue_layers(services, models, true)
  end

  def setup
    User.current      = User.find(users(:admin))
    @acme_corporation = get_organization(:organization1)

    @library          = KTEnvironment.find(katello_environments(:library).id)
    @dev              = KTEnvironment.find(katello_environments(:dev).id)
    @default_view     = ContentView.find(katello_content_views(:acme_default))
    @library_view     = ContentView.find(katello_content_views(:library_view))
    @library_dev_view = ContentView.find(katello_content_views(:library_dev_view))
  end

  def test_create
    assert ContentView.create(FactoryGirl.attributes_for(:content_view))
  end

  def test_label
    content_view = FactoryGirl.build(:content_view)
    content_view.label = ""
    assert content_view.save
    assert content_view.label.present?
  end

  def test_create
    content_view = FactoryGirl.build(:content_view)
    assert content_view.save
  end

  def test_bad_name
    content_view = FactoryGirl.build(:content_view, :name => "")
    assert content_view.invalid?
    refute content_view.save
    assert content_view.errors.include?(:name)
  end

  def test_duplicate_name
    attrs = FactoryGirl.attributes_for(:content_view,
                                       :name => @library_dev_view.name
                                      )
    assert_raises(ActiveRecord::RecordInvalid) do
      ContentView.create!(attrs)
    end
    cv = ContentView.create(attrs)
    refute cv.persisted?
    refute cv.save
  end

  def test_bad_label
    content_view = FactoryGirl.build(:content_view)
    content_view.label = "Bad Label"

    assert content_view.invalid?
    assert_equal 1, content_view.errors.size
    assert content_view.errors.include?(:label)
  end

  def test_content_view_environments
    assert_includes @library_view.environments, @library
    assert_includes @library.content_views, @library_view
  end

  def test_environment_content_view_env_destroy
    env = @dev
    cve = env.content_views.first.content_view_environments.where(:environment_id=>env.id).first
    env.destroy
    assert_nil ContentViewEnvironment.find_by_id(cve.id)
  end

  def test_changesets
    skip "TODO: Fix content views"
    content_view = FactoryGirl.create(:content_view)
    environment = FactoryGirl.create(:environment,
              :prior => content_view.organization.library,
              :organization => content_view.organization)
    changeset = FactoryGirl.create(:changeset, :environment => environment)
    content_view.changesets << changeset
    assert_includes changeset.content_views.map(&:id), content_view.id
    assert_equal content_view.changeset_content_views,
      changeset.changeset_content_views
  end

  def test_promote
    skip "TODO: Fix content views"
    Repository.any_instance.stubs(:clone_contents).returns([])
    Repository.any_instance.stubs(:checksum_type).returns(nil)
    Repository.any_instance.stubs(:uri).returns('http://test_uri/')
    Repository.any_instance.stubs(:bootable_distribution).returns(nil)
    content_view = @library_view
    refute_includes content_view.environments, @dev
    content_view.promote(@library, @dev)
    assert_includes content_view.environments, @dev
    refute_empty ContentViewEnvironment.where(:content_view_id => content_view,
                                                :environment_id => @dev)
  end

  def test_destroy
    skip "TODO: Fix content views"
    count = ContentView.count
    refute @library_dev_view.destroy
    assert ContentView.exists?(@library_dev_view.id)
    assert_equal count, ContentView.count
    assert @library_view.destroy
    assert_equal count-1, ContentView.count
  end

  def test_delete
    skip "TODO: Fix content views"
    view = @library_dev_view
    view.delete(@dev)
    refute_includes view.environments, @dev
  end

  def test_delete_last_env
    skip "TODO: Fix content views"
    view = @library_view
    view.delete(@library)
    assert_empty ContentView.where(:label=>view.label)
  end

  def test_default_scope
    refute_empty ContentView.default
    assert_empty ContentView.default.select{|v| !v.default}
    assert_includes ContentView.default, @library.default_content_view
  end

  def test_non_default_scope
    refute_empty ContentView.non_default
    assert_empty ContentView.non_default.select{|v| v.default}
  end

  def test_destroy_content_view_versions
    skip "TODO: Fix content views"
    content_view = @library_view
    content_view_version = @library_view.versions.first
    refute_nil content_view_version
    assert content_view.destroy
    assert_nil ContentViewVersion.find_by_id(content_view_version.id)
  end

  def test_all_version_library_instances_empty
    assert_empty @library_dev_view.all_version_library_instances
  end

  def test_all_version_library_instances_empty
    refute_empty @library_view.all_version_library_instances
  end

  def test_components_not_in_env
    skip "TODO: Fix content view composites and components"
    composite_view = katello_content_views(:composite_view)

    assert_equal 2, composite_view.components_not_in_env(@dev).length
    assert_equal composite_view.content_view_definition.component_content_views.sort,
      composite_view.components_not_in_env(@dev).sort
  end
end
end
