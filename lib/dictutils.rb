def load_exclude_dict
  CONFIG_DIR = File.join((ENV["XDG_CONFIG_HOME"] || [ENV["HOME"], ".config"]), "mozcdic-ext")
  EXCLUDE_DICT = []
  if File.exist? File.join CONFIG_DIR, "exclude.txt"
    exd = File.read File.join CONFIG_DIR, "exclude.txt"
    exd.each_line do |line|
      x, y = line.chomp.split("\t")
      next if !x || !y || x.empty? || y.empty?
      EXCLUDE_DICT.push([x, y])
    end
  end
end

def exclude_word? yomi, base
  EXCLUDE_DICT.any? do |i|
    File.fnmatch?(i[0], yomi) && File.fnmatch?(i[1], base)
  end
end