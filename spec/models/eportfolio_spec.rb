#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe Eportfolio do
  describe "validations" do
    describe "spam_status" do
      before(:once) do
        @user = User.create!
        @eportfolio = Eportfolio.new(user: @user, name: 'an eportfolio')
      end

      it "is valid when spam_status is nil" do
        @eportfolio.spam_status = nil
        expect(@eportfolio).to be_valid
      end

      it "is valid when spam_status is 'marked_as_spam'" do
        @eportfolio.spam_status = 'marked_as_spam'
        expect(@eportfolio).to be_valid
      end

      it "is valid when spam_status is 'marked_as_safe'" do
        @eportfolio.spam_status = 'marked_as_safe'
        expect(@eportfolio).to be_valid
      end

      it "is valid when spam_status is 'flagged_as_possible_spam'" do
        @eportfolio.spam_status = 'flagged_as_possible_spam'
        expect(@eportfolio).to be_valid
      end

      it "is invalid when spam_status is not nil, 'marked_as_spam', 'marked_as_safe', or 'flagged_as_possible_spam'" do
        @eportfolio.spam_status = 'a_new_status'
        expect(@eportfolio).to be_invalid
      end
    end
  end

  describe "permissions" do
    before(:once) do
      @student = User.create!
      @student.account_users.create!(account: Account.default, role: student_role)
      @eportfolio = Eportfolio.create!(user: @student, name: 'an eportfolio')
      @eportfolio.user.account.enable_feature!(:eportfolio_moderation)
    end

    describe ":update" do
      it "cannot update if not active" do
        @eportfolio.destroy
        expect(@eportfolio.grants_right?(@student, :update)).to be false
      end

      it "cannot update if the user is not the author" do
        new_user = User.create!
        @eportfolio.destroy
        expect(@eportfolio.grants_right?(new_user, :update)).to be false
      end

      it "cannot update if eportfolios are disabled" do
        account = Account.default
        account.settings[:enable_eportfolios] = false
        account.save!
        expect(@eportfolio.grants_right?(@student, :update)).to be false
      end

      it "cannot update if the eportfolio is flagged as possible spam" do
        @eportfolio.update!(spam_status: 'flagged_as_possible_spam')
        expect(@eportfolio.grants_right?(@student, :update)).to be false
      end

      it "can update if the eportfolio is flagged as possible spam and the release flag is disabled" do
        @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
        @eportfolio.update!(spam_status: 'flagged_as_possible_spam')
        expect(@eportfolio.grants_right?(@student, :update)).to be true
      end

      it "cannot update if the eportfolio is marked as spam" do
        @eportfolio.update!(spam_status: 'marked_as_spam')
        expect(@eportfolio.grants_right?(@student, :update)).to be false
      end

      it "can update if the eportfolio is marked as spam and the release flag is disabled" do
        @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
        @eportfolio.update!(spam_status: 'marked_as_spam')
        expect(@eportfolio.grants_right?(@student, :update)).to be true
      end

      it "can update if active, the user is the author, eportfolios are enabled, and not spam" do
        expect(@eportfolio.grants_right?(@student, :update)).to be true
      end
    end

    describe ":manage" do
      before(:once) do
        @eportfolio.user.account.enable_feature!(:eportfolio_moderation)
      end

      it "cannot manage if not active" do
        @eportfolio.destroy
        expect(@eportfolio.grants_right?(@student, :manage)).to be false
      end

      it "cannot manage if the user is not the author" do
        new_user = User.create!
        @eportfolio.destroy
        expect(@eportfolio.grants_right?(new_user, :manage)).to be false
      end

      it "cannot manage if eportfolios are disabled" do
        account = Account.default
        account.settings[:enable_eportfolios] = false
        account.save!
        expect(@eportfolio.grants_right?(@student, :manage)).to be false
      end

      it "cannot manage if the eportfolio is flagged as possible spam" do
        @eportfolio.update!(spam_status: 'flagged_as_possible_spam')
        expect(@eportfolio.grants_right?(@student, :manage)).to be false
      end

      it "can manage if the eportfolio is flagged as possible spam and the release flag is disabled" do
        @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
        @eportfolio.update!(spam_status: 'flagged_as_possible_spam')
        expect(@eportfolio.grants_right?(@student, :manage)).to be true
      end

      it "cannot manage if the eportfolio is marked as spam" do
        @eportfolio.update!(spam_status: 'marked_as_spam')
        expect(@eportfolio.grants_right?(@student, :manage)).to be false
      end

      it "can manage if the eportfolio is marked as spam and the release flag is disabled" do
        @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
        @eportfolio.update!(spam_status: 'marked_as_spam')
        expect(@eportfolio.grants_right?(@student, :manage)).to be true
      end

      it "can manage if active, the user is the author, eportfolios are enabled, and not spam" do
        expect(@eportfolio.grants_right?(@student, :manage)).to be true
      end
    end

    describe ":moderate" do
      before(:once) do
        @admin = account_admin_user
      end

      it "cannot moderate if the eportfolio is not active" do
        @eportfolio.destroy
        expect(@eportfolio.grants_right?(@admin, :moderate)).to be false
      end

      it "cannot moderate if the user is the author" do
        eportfolio = Eportfolio.create!(user: @admin, name: 'admin eportfolio')
        expect(eportfolio.grants_right?(@admin, :moderate)).to be false
      end

      it "cannot moderate if the user does not have permission to moderate user content" do
        Account.default.role_overrides.create!(role: admin_role, enabled: false, permission: :moderate_user_content)
        expect(@eportfolio.grants_right?(@admin, :moderate)).to be false
      end

      it "can moderate if the eportfolio is active, user is not the author, and user can moderate user content" do
        Account.default.role_overrides.create!(role: admin_role, enabled: true, permission: :moderate_user_content)
        expect(@eportfolio.grants_right?(@admin, :moderate)).to be true
      end
    end

    describe ":read" do
      before(:once) do
        @admin = account_admin_user
      end

      context "when the eportfolio is spam" do
        before(:once) do
          @eportfolio.update!(spam_status: 'marked_as_spam')
        end

        it "cannot read if the eportfolio is not active" do
          @eportfolio.destroy
          expect(@eportfolio.grants_right?(@admin, :read)).to be false
        end

        it "can read if the eportfolio is active and user is the author" do
          expect(@eportfolio.grants_right?(@student, :read)).to be true
        end

        it "cannot read if the user does not have permission to moderate user content" do
          Account.default.role_overrides.create!(role: admin_role, enabled: false, permission: :moderate_user_content)
          expect(@eportfolio.grants_right?(@admin, :read)).to be false
        end

        it "can read if the eportfolio is active and the user can moderate user content" do
          Account.default.role_overrides.create!(role: admin_role, enabled: true, permission: :moderate_user_content)
          expect(@eportfolio.grants_right?(@admin, :read)).to be true
        end
      end
    end
  end

  describe "#flagged_as_possible_spam?" do
    before(:once) do
      @student = User.create!
      @eportfolio = Eportfolio.new(user: @student, name: 'an eportfolio')
      @eportfolio.user.account.enable_feature!(:eportfolio_moderation)
    end

    it "returns true if flagged as possible spam" do
      @eportfolio.spam_status = "flagged_as_possible_spam"
      expect(@eportfolio).to be_flagged_as_possible_spam
    end

    it "returns false if flagged as possible spam and the release flag is disabled" do
      @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
      @eportfolio.spam_status = "flagged_as_possible_spam"
      expect(@eportfolio).not_to be_flagged_as_possible_spam
    end

    it "returns false if marked as spam" do
      @eportfolio.spam_status = "marked_as_spam"
      expect(@eportfolio).not_to be_flagged_as_possible_spam
    end

    it "returns false if spam status has not been set" do
      expect(@eportfolio).not_to be_flagged_as_possible_spam
    end
  end

  describe "#spam?" do
    before(:once) do
      @student = User.create!
      @eportfolio = Eportfolio.new(user: @student, name: 'an eportfolio')
      @eportfolio.user.account.enable_feature!(:eportfolio_moderation)
    end

    it "returns true if marked as spam" do
      @eportfolio.spam_status = "marked_as_spam"
      expect(@eportfolio).to be_spam
    end

    it "returns false if marked as spam and the release flag is disabled" do
      @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
      @eportfolio.spam_status = "marked_as_spam"
      expect(@eportfolio).not_to be_spam
    end

    it "returns true if flagged as possible spam" do
      @eportfolio.spam_status = "flagged_as_possible_spam"
      expect(@eportfolio).to be_spam
    end

    it "returns false if flagged as possible spam and the release flag is disabled" do
      @eportfolio.user.account.disable_feature!(:eportfolio_moderation)
      @eportfolio.spam_status = "flagged_as_possible_spam"
      expect(@eportfolio).not_to be_spam
    end

    it "returns false when passed include_possible_spam: false if flagged as possible spam" do
      @eportfolio.spam_status = "flagged_as_possible_spam"
      expect(@eportfolio.spam?(include_possible_spam: false)).to be false
    end

    it "returns false if spam status has not been set" do
      expect(@eportfolio).not_to be_spam
    end
  end

  describe "#ensure_defaults" do
    before(:once) do
      eportfolio
    end

    it "should create a category if one doesn't exist" do
      expect(@portfolio.eportfolio_categories).to be_empty
      @portfolio.ensure_defaults
      expect(@portfolio.reload.eportfolio_categories).not_to be_empty
    end

    it "should create an entry in the first category if one doesn't exist" do
      @category = @portfolio.eportfolio_categories.create!(:name => "Hi")
      expect(@category.eportfolio_entries).to be_empty
      @portfolio.ensure_defaults
      expect(@category.reload.eportfolio_entries).not_to be_empty
    end
  end

  describe "callbacks" do
    describe "#check_for_spam" do
      let(:user) { User.create! }
      let(:eportfolio) { Eportfolio.create!(name: "my file", user: user) }
      let(:spam_status) { eportfolio.reload.spam_status }

      context "when the setting has a value and the release flag is enabled" do
        before(:each) do
          user.account.root_account.enable_feature!(:eportfolio_moderation)
          Setting.set('eportfolio_title_spam_keywords', 'bad, verybad, worse')
        end

        it "marks as possible spam when the title matches one or more keywords" do
          eportfolio.update!(name: "my verybad page")
          expect(spam_status).to eq "flagged_as_possible_spam"
        end

        it "does not mark as spam when the title matches no keywords" do
          expect {
            eportfolio.update!(name: "my great and notbad page")
          }.not_to change { spam_status }
        end

        it "does not mark as spam if a spam_status already exists" do
          eportfolio.update!(spam_status: "marked_as_safe")

          expect {
            eportfolio.update!(name: "actually a bad page")
          }.not_to change { spam_status }
        end
      end

      it "does not attempt to mark as spam when the setting is empty" do
        user.account.root_account.enable_feature!(:eportfolio_moderation)
        expect {
          eportfolio.update!(name: "actually a bad page")
        }.not_to change { spam_status }
      end

      it "does not attempt to mark as spam when the release flag is not enabled" do
        Setting.set('eportfolio_title_spam_keywords', 'bad, verybad, worse')
        expect {
          eportfolio.update!(name: "actually a bad page")
        }.not_to change { spam_status }
      end
    end
  end
end
