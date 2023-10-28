def load_exclude_dict
  $config_dir = File.join((ENV["XDG_CONFIG_HOME"] || [ENV["HOME"], ".config"]), "mozcdict-ext")
  $exclude_dict = []
  if File.exist? File.join $config_dir, "exclude.txt"
    exd = File.read File.join $config_dir, "exclude.txt"
    exd.each_line do |line|
      x, y = line.strip.split(/\s+/, 2)
      next if !x || !y || x.empty? || y.empty?
      $exclude_dict.push([x, y])
    end
  end
end

def exclude_word? yomi, base
  $exclude_dict.any? do |i|
    File.fnmatch?(i[0], yomi) && File.fnmatch?(i[1], base)
  end
end