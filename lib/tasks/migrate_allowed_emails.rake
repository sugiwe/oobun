namespace :allowed_users do
  desc "Migrate existing users to AllowedUser table"
  task migrate_existing: :environment do
    puts "=" * 80
    puts "AllowedUser Migration Task"
    puts "=" * 80
    puts

    # 1. 既存のすべてのユーザーをAllowedUserに追加
    puts "Step 1: Adding all existing users to AllowedUser table..."
    added_count = 0
    skipped_count = 0

    User.find_each do |user|
      if AllowedUser.exists?(email: user.email)
        puts "  [SKIP] #{user.email} - already exists"
        skipped_count += 1
      else
        AllowedUser.create!(
          email: user.email,
          added_by_admin: true,
          note: "既存ユーザー（自動移行）",
          contacted: false
        )
        puts "  [ADD]  #{user.email}"
        added_count += 1
      end
    end

    puts
    puts "Step 1 Complete:"
    puts "  - Added: #{added_count} users"
    puts "  - Skipped: #{skipped_count} users (already existed)"
    puts

    # 2. ALLOWED_EMAILS環境変数からメールアドレスを読み込んで追加
    if ENV["ALLOWED_EMAILS"].present?
      puts "Step 2: Adding emails from ALLOWED_EMAILS environment variable..."
      emails = ENV["ALLOWED_EMAILS"].split(",").map(&:strip)
      env_added_count = 0
      env_skipped_count = 0

      emails.each do |email|
        next if email.blank?

        if AllowedUser.exists?(email: email)
          puts "  [SKIP] #{email} - already exists"
          env_skipped_count += 1
        else
          AllowedUser.create!(
            email: email,
            added_by_admin: true,
            note: "環境変数から移行",
            contacted: false
          )
          puts "  [ADD]  #{email}"
          env_added_count += 1
        end
      end

      puts
      puts "Step 2 Complete:"
      puts "  - Added: #{env_added_count} emails"
      puts "  - Skipped: #{env_skipped_count} emails (already existed)"
      puts
    else
      puts "Step 2: Skipped (ALLOWED_EMAILS environment variable not set)"
      puts
    end

    # 3. 統計情報表示
    puts "=" * 80
    puts "Migration Summary"
    puts "=" * 80
    puts "Total AllowedUser records: #{AllowedUser.count}"
    puts "  - Added by admin: #{AllowedUser.added_by_admin.count}"
    puts "  - Added by invitation: #{AllowedUser.added_by_invitation.count}"
    puts "  - Contacted: #{AllowedUser.contacted.count}"
    puts "  - Not contacted: #{AllowedUser.not_contacted.count}"
    puts
    puts "Migration complete!"
    puts
    puts "Next steps:"
    puts "1. Review the AllowedUser table: rails console"
    puts "   > AllowedUser.all"
    puts "2. Remove ALLOWED_EMAILS from .kamal/secrets after confirming"
    puts "3. Deploy the changes: bin/kamal deploy"
    puts "=" * 80
  end

  desc "Display current AllowedUser statistics"
  task stats: :environment do
    puts "=" * 80
    puts "AllowedUser Statistics"
    puts "=" * 80
    puts "Total records: #{AllowedUser.count}"
    puts "  - Added by admin: #{AllowedUser.added_by_admin.count}"
    puts "  - Added by invitation: #{AllowedUser.added_by_invitation.count}"
    puts "  - Contacted: #{AllowedUser.contacted.count}"
    puts "  - Not contacted: #{AllowedUser.not_contacted.count}"
    puts "=" * 80
  end
end
