puts ' ruby版本已过时'
def config_u_drive
  system('sudo spctl --master-disable')

  unless system('command -v swift >/dev/null')
    system('xcode-select --install')
  end

  unless system('command -v brew >/dev/null')
    system('/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"')
  end

  unless File.exist?('/System/Volumes/Data/' + `which ntfs-3g`.strip)
    system('brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac')
  end

  ARGV.each do |i|
    once_cut_val = File.dirname(i)
    twice_cut_val = once_cut_val.split('//').last
    thrice_cut_val = File.basename(i)

    puts "新设备: #{thrice_cut_val}"
    system("sudo umount #{i}")
    system("/System/Volumes/Data/#{`which ntfs-3g`.strip} /dev/#{twice_cut_val} '/Volumes/#{thrice_cut_val}' -olocal -oallow_other -oauto_xattr -ovolname='#{thrice_cut_val}'")
    puts "新设备: #{thrice_cut_val}，已可读写！"
    puts '---------'
    puts ' '
  end
end

puts ' '
puts ' '
puts '等待NTFS新设备接入'
puts ' '
puts '---------'
puts ' '

while true
  sleep 5
  new_dev = `mount | grep ntfs | awk -F ' ' '{print $1}'`.strip
  if new_dev.empty?
    a = 1 # 无意义，过语法检测
  else
    config_u_drive(new_dev)
  end
end
