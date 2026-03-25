class AddInvitationTypeAndExpiryToInvitations < ActiveRecord::Migration[8.1]
  def up
    add_column :invitations, :invitation_type, :string, default: "single_use", null: false
    add_column :invitations, :expiry_type, :string, default: "seven_days", null: false
    add_column :invitations, :use_count, :integer, default: 0, null: false
    add_column :invitations, :last_used_at, :datetime

    # 既存の招待を single_use + seven_days に設定
    Invitation.update_all(invitation_type: "single_use", expiry_type: "seven_days", use_count: 0)

    # accepted_at が設定されている招待は use_count を 1 に設定
    Invitation.where.not(accepted_at: nil).update_all(use_count: 1, last_used_at: Invitation.arel_table[:accepted_at])
  end

  def down
    remove_column :invitations, :invitation_type
    remove_column :invitations, :expiry_type
    remove_column :invitations, :use_count
    remove_column :invitations, :last_used_at
  end
end
