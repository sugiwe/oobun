# サンプル交換日記のSeed
# 実行方法: bin/rails db:seed (db/seeds.rbから呼び出される)

# Active Storageで画像をアタッチするヘルパーメソッド
def attach_image_from_assets(record, attachment_name, file_path)
  full_path = Rails.root.join("app/assets/images/samples/#{file_path}").to_s
  unless File.exist?(full_path)
    puts "⚠️  画像ファイルが見つかりません: #{full_path}"
    return
  end

  record.public_send(attachment_name).attach(
    io: File.open(full_path),
    filename: File.basename(file_path),
    content_type: Marcel::MimeType.for(Pathname.new(full_path))
  )
end

puts "🌱 サンプル交換日記のSeedを開始します..."

# ========================================
# 1. サンプルユーザーを作成
# ========================================

sakura = User.find_or_create_by!(username: "bloomy_s") do |u|
  u.display_name = "さくら"
  u.email = "sample.sakura@example.com"
  u.bio = "Webエンジニア / SF好き / 読書とコーヒーが好き\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(sakura, :avatar, "avatars/sakura.jpg")

kenta = User.find_or_create_by!(username: "kenkenken") do |u|
  u.display_name = "けんた"
  u.email = "sample.kenta@example.com"
  u.bio = "UIデザイナー / SF初心者 / デザインと音楽が好き\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(kenta, :avatar, "avatars/kenta.jpg")

ayumi = User.find_or_create_by!(username: "ayu0901") do |u|
  u.display_name = "あゆみ"
  u.email = "sample.ayumi@example.com"
  u.bio = "大学3年生 / 文学部 / レポートと就活で夜型生活\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(ayumi, :avatar, "avatars/ayumi.jpg")

takeru = User.find_or_create_by!(username: "takeru_camera") do |u|
  u.display_name = "たける"
  u.email = "sample.takeru@example.com"
  u.bio = "大学2年生 / 情報系 / 写真とプログラミングが好き\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(takeru, :avatar, "avatars/takeru.jpg")

yui = User.find_or_create_by!(username: "ytkmr42") do |u|
  u.display_name = "ゆい"
  u.email = "sample.yui@example.com"
  u.bio = "大学1年生 / 経済学部 / カフェでバイト中\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(yui, :avatar, "avatars/yui.jpg")

mai = User.find_or_create_by!(username: "my-tnk") do |u|
  u.display_name = "まい"
  u.email = "sample.mai@example.com"
  u.bio = "小学校教員 / 子どもたちの未来を考える / 読書と料理が好き\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(mai, :avatar, "avatars/mai.jpg")

ryo = User.find_or_create_by!(username: "moduryo") do |u|
  u.display_name = "りょう"
  u.email = "sample.ryo@example.com"
  u.bio = "AIエンジニア / スタートアップ勤務 / 技術で社会を変えたい\n※coconikkiサンプル交換日記用のアカウントです"
end
attach_image_from_assets(ryo, :avatar, "avatars/ryo.jpg")

puts "✅ サンプルユーザー7人を作成しました"

# ========================================
# 2. パターン1: 三体読書日記
# ========================================

santai_thread = CorrespondenceThread.find_or_create_by!(slug: "sample-santai") do |t|
  t.title = "さくけんの『三体』読書会"
  t.description = "話題のSF小説『三体』を2人で読み進めながら、感想を交換していく読書日記です。⚠️この交換日記は『三体』へのネタバレを含みますのでご注意ください！\n\n※この交換日記はcoconikkiのサンプルです（ダミーアカウントによる架空の内容です）"
  t.status = "free"
  t.show_in_list = true
  t.turn_based = true
  t.is_sample = true
end
attach_image_from_assets(santai_thread, :thumbnail, "covers/santai.jpg")

# メンバーシップ作成
Membership.find_or_create_by!(thread: santai_thread, user: sakura) { |m| m.position = 1 }
Membership.find_or_create_by!(thread: santai_thread, user: kenta) { |m| m.position = 2 }

# 投稿1: さくら
Post.find_or_create_by!(thread: santai_thread, user: sakura, title: "三体、ついに買った") do |p|
  p.body = <<~BODY
    念願の『三体』を買ってきました。Netflixのドラマの評判がすごくて観たいと思ってるんだけど、その前に原作読んでおこうかなって。表紙からして雰囲気あるね。

    中国SF、初めて読むからちょっと不安だけど期待。劉慈欣って作家さん、世界的に評価されてるらしいね。
    けんたも一緒に読むって言ってくれたから、ネタバレしないように進めていこう。今日は第1部の冒頭だけ読んだけど、文化大革命から始まるのが意外だった。SFというより歴史小説みたいなスタート。

    これからどうなるんだろう。めっちゃ分厚いから完走できるかちょっと不安でもある笑
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-01 20:00")
end

# 投稿2: けんた
Post.find_or_create_by!(thread: santai_thread, user: kenta, title: "僕も買った！一緒に読もう") do |p|
  p.body = <<~BODY
    さくらに勧められて、僕も買ってきました。
    書店でまだ平積みされてて、帯に「世界で2900万部突破」って書いてあって驚いた。そんなに売れてるんだ。SF好きの友達が「人生変わる」って言ってたのを思い出した。正直、中国の小説ってあまり読んだことないから新鮮。ページをめくると独特の雰囲気があるね。翻訳も読みやすい。一緒に読み進められるの楽しみ。

    SNSだとネタバレ踏みそうで怖いけど、ここなら安心して感想言えるのがいい。ゆっくり読んでいこう。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-03 19:30")
end

# 投稿3: さくら
Post.find_or_create_by!(thread: santai_thread, user: sakura, title: "第1部読了。葉文潔の人生が重い") do |p|
  p.body = <<~BODY
    第1部を読み終えました。
    文化大革命のシーンが本当に重くて、葉文潔の人生があまりにも過酷で...。父親を目の前で批判され、自分も下放されて、さらに信じた人に裏切られて…。彼女がなぜああいう選択をしたのか、ちょっと理解できてしまう自分がいる。人間不信になるのも無理ないよね。

    それにしても、紅岸基地のくだりがすごく緊張感あった。あの巨大なアンテナで何をしてたのか、ようやく分かったときの衝撃。SFとしての面白さもあるけど、人間ドラマとしても深い。

    けんた、どこまで読んだ？
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-07 22:15")
end

# 投稿4: けんた
Post.find_or_create_by!(thread: santai_thread, user: kenta, title: "やっと追いついた。人間ドラマとして読んでる") do |p|
  p.body = <<~BODY
    遅ればせながら、第1部を読了しました。
    葉文潔の人生、本当につらい。SFだと思って読み始めたのに、完全に人間ドラマとして引き込まれてる。時代背景も重いし、彼女の選択も切ない。
    あと、科学者たちの描写がリアルだなって思った。物理学の話も出てくるけど、専門知識なくても読める工夫がされてる感じがありがたい。

    さくらの言う通り、ここまでの展開は想像してなかった。SFというより、ヒューマンドラマ。
    第2部からどう転がっていくのか気になる。続きを読むのが楽しみだ〜。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-10 21:00")
end

# 投稿5: さくら
Post.find_or_create_by!(thread: santai_thread, user: sakura, title: "三体ゲームのパートが最高に面白い！") do |p|
  p.body = <<~BODY
    第2部に入って、三体ゲームのパートがめちゃくちゃ面白い！
    VRMMOみたいな設定で、プレイヤーが三体文明の謎を解いていくっていうのがホントヤバい。脱水と浸潤のギミックとか、3つの太陽が予測不能に動く環境とか、どうやってこんな設定考えたんだろう。

    エンジニア視点で読むと、このゲームを実装するならどうするかなって考えちゃう。物理エンジンどうする？とか。そして、このゲームが物語全体にどう絡んでくるのかがワクワクする。
    劉慈欣の想像力すごすぎ。けんたはデザイナー視点だとどう見える？
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-14 20:45")
end

# 投稿6: けんた
Post.find_or_create_by!(thread: santai_thread, user: kenta, title: "世界観デザインの教科書みたい") do |p|
  p.body = <<~BODY
    三体ゲーム、デザイナー視点でも超面白い！あの過酷な環境をビジュアルでどう表現するか、めっちゃ考えながら読んでた。3つの太陽が同時に昇るシーンとか、脱水状態の人間とか、映像で見たらすごそう。Netflix版でどう描かれるのか今から楽しみ。

    あと、ゲーム内で歴史上の人物が登場する演出も好き。ニュートンとか出てくるのが意外で面白かった。世界観の作り込み方が本当に丁寧。
    これSFだけど、デザインやクリエイティブの参考書としても読める。面白すぎてどんどん読んじゃうね。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-17 19:20")
end

# 最終投稿メタデータを更新
santai_thread.update_last_post_metadata!

puts "✅ パターン1: 三体読書日記を作成しました（6投稿）"

# ========================================
# 3. パターン2: 大学生3人のランニング習慣チャレンジ
# ========================================

running_thread = CorrespondenceThread.find_or_create_by!(slug: "sample-running") do |t|
  t.title = "週3ランニングを習慣化するための集い"
  t.description = "大学生3人で、週3回のランニングを習慣化するチャレンジ。まずは1ヶ月続けることを目指します！お互いに報告し合って、習慣化を目指す日記です。\n\n※この交換日記はcoconikkiのサンプルです（ダミーアカウントによる架空の内容です）"
  t.status = "free"
  t.show_in_list = true
  t.turn_based = false
  t.is_sample = true
end
attach_image_from_assets(running_thread, :thumbnail, "covers/running.jpg")

# メンバーシップ作成
Membership.find_or_create_by!(thread: running_thread, user: ayumi) { |m| m.position = 1 }
Membership.find_or_create_by!(thread: running_thread, user: takeru) { |m| m.position = 2 }
Membership.find_or_create_by!(thread: running_thread, user: yui) { |m| m.position = 3 }

# 投稿1: あゆみ
post1 = Post.find_or_create_by!(thread: running_thread, user: ayumi, title: "今日からランニング始めます") do |p|
  p.body = <<~BODY
    今日から週3ランニング始めることにしました🏃‍♂️

    レポートと就活準備で夜更かし続きで、完全に体調崩し気味。このままじゃまずいなって思って。とりあえず朝6時に起きて、大学の周りを20分走ってきた。息切れがやばい...完全に運動不足を実感。
    でも、走り終わった後の爽快感はいいね。朝の空気が気持ちよくて、こんな時間に外出るの久しぶりだなって。途中、パン屋さんの前を通ったら焼きたての匂いがして、走った後のご褒美に買っちゃった。

    目標は週3回、1ヶ月続けること。まずは1週間頑張ります。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-05 07:30")
end
attach_image_from_assets(post1, :thumbnail, "thumbnails/running-post-1.jpg")

# 投稿2: たける
post2 = Post.find_or_create_by!(thread: running_thread, user: takeru, title: "僕も参加します") do |p|
  p.body = <<~BODY
    あゆみの投稿見て、僕も今朝走ってきました。
    サークルの先輩に「朝ラン始めたら人生変わる」って言われてたのを思い出して。5km走ろうと思ったけど、2kmで挫折しました😇
    でも、朝の光がきれいで、思わず写真撮っちゃった。川沿いのコースを走ったんだけど、朝日が水面に反射してて最高だった。

    情報系の授業で夜遅くまでコード書いてること多いから、朝型生活に変えたいんだよね。あゆみと一緒にやれるの心強い。
    お互い報告し合って、サボらないようにしよう。今週は3回走るのが目標。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-06 08:15")
end
attach_image_from_assets(post2, :thumbnail, "thumbnails/running-post-2.jpg")

# 投稿3: ゆい
Post.find_or_create_by!(thread: running_thread, user: yui, title: "私も入れてください！") do |p|
  p.body = <<~BODY
    二人の投稿見てたら、私も参加したくなっちゃったのであゆみさんに招待してもらいました。

    実は昨日カフェのバイト明けで家帰ったの夜中の2時で、今朝起きれるか不安だったけど、頑張って6時半に起きて走ってきた。眠すぎて最初はきつかったけど、走ってたら目が覚めてきた。

    バイトで夜遅い生活が続いてて、生活リズムやばいなって自覚はあったから、ちょうどいい機会かも。
    正直、運動めっちゃ苦手だけど、3人でやるなら続けられそう。
    あゆみさんとたけるさんの投稿読むとモチベ上がります、1年生だけど混ぜてください！一緒に頑張ります。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-07 07:00")
end

# 投稿4: あゆみ
post4 = Post.find_or_create_by!(thread: running_thread, user: ayumi, title: "3人で頑張ろう！") do |p|
  p.body = <<~BODY
    ゆいも参加してくれて嬉しい！3人でやると楽しいね。

    今日は4日目。朝ランの途中で、いつも同じ場所にいる猫を見つけた。白黒の模様がかわいい猫で、毎朝そこでのんびりしてる。今日は近づいても逃げなくて、ちょっと触れた。癒された...☺️
    走るだけじゃなくて、こういう小さな発見があるのもいいね。

    たけるの朝日の写真、すごくきれいだった。私も今度撮ってみようかな。
    ゆい、バイト明けで走るのすごい。
    私は夜型だから朝起きるのきついけど、お互いマイペースで続けていこう。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-09 08:00")
end
attach_image_from_assets(post4, :thumbnail, "thumbnails/running-post-4.jpg")

# 投稿5: たける
Post.find_or_create_by!(thread: running_thread, user: takeru, title: "今週2回しか走れなかった") do |p|
  p.body = <<~BODY
    今週は2回しか走れなかったっす...。
    プログラミングの課題が予想以上に大変で、朝まで作業してたら走る時間取れなくて。目標の週3には届かなかったけど、ゼロじゃないからまだマシかな。完璧にやろうとすると続かないから、できる範囲でやっていこうと思う。

    あゆみの猫の話、いいな。僕も今度探してみよう。
    ゆいの「眠いけど頑張る」って姿勢、すごいと思う。バイトしながら朝ラン、尊敬する。でもちゃんと寝てね💤
    来週はもうちょっと計画的に時間作って、3回走れるようにしたい。
    3人で報告し合えるの、本当にありがたいな〜。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-12 21:00")
end

# 投稿6: ゆい
post6 = Post.find_or_create_by!(thread: running_thread, user: yui, title: "私も1回だけ...でもゼロじゃない") do |p|
  p.body = <<~BODY
    たけるさんの気持ちわかります、今週は私も1回しか走れなかった。バイトのシフトが急に増えて、朝起きれなくて。でも、「1回でもゼロよりマシ」って自分に言い聞かせてる。完璧主義だと続かないですよね。
    昨日は夜ランに切り替えてみた。バイト終わりの22時から走るのもありかなって。夜の方が涼しいし、人も少ないから走りやすい。ただ、暗いからちょっと怖かったけど。

    あゆみさんの猫、かわいい〜🥰 私も探してみる。
    たけるさんの課題、お疲れ様です。来週はお互い無理しない範囲で、できるときに走りましょう◎
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-14 23:30")
end
attach_image_from_assets(post6, :thumbnail, "thumbnails/running-post-6.jpg")

# 投稿7: あゆみ
Post.find_or_create_by!(thread: running_thread, user: ayumi, title: "マイペースでいこう") do |p|
  p.body = <<~BODY
    たけるもゆいも無理しないでね。
    私も今週は2回だった。就活の準備で説明会とか行ってて、朝走る時間がなかなか取れなくて。でも、走ると頭がすっきりして、その後の作業がはかどる気がする。

    今日は走りながら、「自分って何がしたいんだろう」とか考えてたよ。就活でいろんな会社見てると、わからなくなってくるんだよね。
    でも、走ってる間は余計なこと考えずに、ただ前に進む感じが好き。

    ゆいの夜ランいいね。時間帯変えるのもありだと思う。
    3人とも続いてるのがすごい。マイペースで頑張ろう。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-17 09:00")
end

# 投稿8: たける
Post.find_or_create_by!(thread: running_thread, user: takeru, title: "少し楽になってきた") do |p|
  p.body = <<~BODY
    3週目に突入しました🎉

    今週は3回走れた！少し楽になってきた気がする。体が慣れてきたのか、息切れも最初ほどじゃない。
    あと、ランニングアプリ入れてみたんだけど、これめっちゃいいよ！距離とかペースが記録されて、データで見るとモチベ上がる。

    プログラミング好きだから、こういうの好き。走ってる最中に、アプリの改善案とか思いついたりして、走ることが思考の整理にもなってる。
    あゆみの「ただ前に進む感じ」わかる〜。シンプルだけど、それがいいんだよね。

    3人とも続いてるの本当にすごいと思う、1ヶ月続けられそうな気がしてきた！
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-19 08:30")
end

# 投稿9: ゆい
Post.find_or_create_by!(thread: running_thread, user: yui, title: "3人でやってるから続いてる") do |p|
  p.body = <<~BODY
    気づいたら3週間続いてて、自分でも驚いてる👀
    一人だったら絶対無理でした、3人で報告し合えるから続いてる。

    昨日、カフェのバイト先で常連さんに「最近顔色いいね」って言われて嬉しかった。友達にも「朝ラン始めた」って言ったら「ゆいが？！」って驚かれたよ、運動嫌いで有名だったから(笑)。
    でも、続けられてる自分がちょっと誇らしい。あゆみさんとたけるさんの投稿読むと、「私も頑張ろう」って思える。
    たけるさんのアプリ、私も入れてみようかな！

    ひとまずの目標の1ヶ月継続まで残り1週間ですね、1ヶ月経った後も継続していきたいです！
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-22 07:45")
end

# 最終投稿メタデータを更新
running_thread.update_last_post_metadata!

puts "✅ パターン2: ランニング習慣チャレンジを作成しました（9投稿、サムネイル4枚）"

# ========================================
# 4. パターン3: AIについて異なる視点から語る
# ========================================

ai_thread = CorrespondenceThread.find_or_create_by!(slug: "sample-ai-talk") do |t|
  t.title = "AIについて思うこと"
  t.description = "小学校教員とAIエンジニアが、それぞれの立場から「AI」について語る対話日記。\n\n※この交換日記はcoconikkiのサンプルです（ダミーアカウントによる架空の内容です）"
  t.status = "free"
  t.show_in_list = true
  t.turn_based = true
  t.is_sample = true
end
attach_image_from_assets(ai_thread, :thumbnail, "covers/ai-talk.jpg")

# メンバーシップ作成
Membership.find_or_create_by!(thread: ai_thread, user: mai) { |m| m.position = 1 }
Membership.find_or_create_by!(thread: ai_thread, user: ryo) { |m| m.position = 2 }

# 投稿1: まい
Post.find_or_create_by!(thread: ai_thread, user: mai, title: "子どもたちに「ChatGPTで宿題やっていい？」って聞かれた") do |p|
  p.body = <<~BODY
    学校でもAIの話題が増えてきました。
    先日、6年生の子に「先生、ChatGPTで宿題やっていい？」って聞かれて、どう答えるか悩みました。「ダメ」って言うのは簡単だけど、彼らが大人になる頃にはAIが当たり前の世界になってるわけで。
    でも「考える力」をどう育てるか、AIがあると余計に難しいなって思います。即使えるように使い方を教えるべきなのか、まず自分で考えることを教えるべきなのか。教育現場でもAIとの向き合い方を模索中です。

    りょうはエンジニアとして、AIについてどう思ってる？
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-03 20:00")
end

# 投稿2: りょう
Post.find_or_create_by!(thread: ai_thread, user: ryo, title: "教育とAIは特に難しそう") do |p|
  p.body = <<~BODY
    まいさんの投稿、リアルで考えさせられました。
    エンジニアとしては、AIはあくまで道具として便利に使っているけど、教育現場ではそう簡単じゃないんだろうな。
    僕らの仕事でも、AIに頼りすぎると危険っていう考え方はあります。AIが生成したコードを全て鵜呑みにしちゃうとか。
    でも、AIを使うことで効率が上がるのも事実だし、ハルシネーション（AIが間違えること）も体感としてかなり減ってきている。
    子どもたちにも、「何をAIに任せて、何を自分で考えるか」を判断する力が必要になるのかもしれないですね。
    教育とAI、めっちゃ興味深いけど難しいテーマだ。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-05 19:30")
end

# 投稿3: まい
Post.find_or_create_by!(thread: ai_thread, user: mai, title: "「道具」って視点はいいね") do |p|
  p.body = <<~BODY
    りょうの「道具」って視点、すごくいいね。
    確かに、電卓も辞書も道具だし、それを使うことが悪いわけじゃない。問題は「考える力」をどう育てるかなんだよね。AIがあると、答えがすぐ手に入るから、試行錯誤する機会が減ってしまう気がする。
    でも、逆にAIを使って「考える時間を増やす」こともできるのかな。たとえば、調べる時間を短縮できた代わりに議論する時間を増やすとか？

    子どもたちには「AIに何を聞くか考える力」が必要なのかもって最近思う。質問力というか、問いを立てる力っていうのかな。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-08 21:00")
end

# 投稿4: りょう
Post.find_or_create_by!(thread: ai_thread, user: ryo, title: "プロンプトエンジニアリングに近いのかも") do |p|
  p.body = <<~BODY
    「AIに何を聞くか考える力」って、プロンプトエンジニアリングの考え方に近いのかもです。
    AIに適切な質問をする能力って、これからめちゃくちゃ重要になると思う。僕らの仕事でも、AIにいい質問ができる人とできない人で、成果が全然違う。

    まいさんの「問いを立てる力」って表現、すごくいいですね。教育現場でそれを教えられたら、子どもたちはAIを使いこなせる大人になるんじゃないかな。
    教育とAI開発、意外と近いのかも。どちらも「考える力」を育てることが目的だし。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-10 20:15")
end

# 投稿5: まい
Post.find_or_create_by!(thread: ai_thread, user: mai, title: "AIとの共存、どう教えるか") do |p|
  p.body = <<~BODY
    りょうの話を聞いて、AIとの共存って避けられないんだなって改めて思いました。
    避けられないんだったら、どう使うかを教える方が建設的だよね。学校でも「AIリテラシー」みたいな授業を取り入れる動きがあるけど、まだまだ手探り状態。先生たち自身がAIに詳しくないというのがいちばんの問題なんだけど、そんなすぐ使いこなして詳しくなれるわけでもないし。
    でも、子どもたちは柔軟だから、ちゃんと教えればすぐ理解すると思う。「AIは便利だけど、全てを任せるんじゃなくて、自分で考えることも大事」って伝えていきたい。
    りょうみたいなエンジニアの視点、参考になるので教育現場にいる身としてはかなりありがたいです🙏
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-13 19:45")
end

# 投稿6: りょう
Post.find_or_create_by!(thread: ai_thread, user: ryo, title: "教育現場から学ぶこと、多い") do |p|
  p.body = <<~BODY
    まいさんの投稿を読んで、エンジニアも教育現場から学ぶべきことが多いかもって思いました。僕らは「どう作るか」ばかり考えてるけど、「どう使われるか」「誰がどう影響を受けるか」をもっと考えないといけない。特に子どもたちへの影響は大きいし。AIを作る側として、責任も感じます。

    まいさんみたいに現場で向き合ってる人の声、もっと聞きたいです。AIリテラシー教育、応援してます。もし何か協力できることがあれば言ってください。技術者として、教育現場に貢献できたら嬉しい。
  BODY
  p.status = "published"
  p.created_at = Time.zone.parse("2026-02-16 21:00")
end

# 最終投稿メタデータを更新
ai_thread.update_last_post_metadata!

puts "✅ パターン3: AI対話を作成しました（6投稿）"

puts "🎉 サンプル交換日記のSeedが完了しました！"
puts "   - ユーザー: 7人"
puts "   - 交換日記: 3件"
puts "   - 投稿: 21件"
puts "   - 画像: アバター7枚 + カバーアート3枚 + サムネイル4枚"
