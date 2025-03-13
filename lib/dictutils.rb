require 'yaml'

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

def load_global_config
  if File.exist? File.join $config_dir, "config.yaml"
    config = YAML.load File.read File.join $config_dir, "config.yaml"
    config.each do |k, v|
      $opts[k.to_sym] = v
    end
  end
end

def check_proper clsexpr
  !$opts[:"no-proper"] && clsexpr.include?("固有名詞")
end

def check_english base, clsexpr
  !$opts[:english] && base =~ /^[\p{ascii}\p{Symbol}\p{In_CJK_Symbols_and_Punctuation}\p{Punctuation}\p{White_Space}]+$/ && (!$opts[:"english-proper"] || !clsexpr.include?("固有名詞"))
end

def check_fullwidth_english base, clsexpr
  (!$opts[:"fullwidth-english"] && base =~ /^[\p{Symbol}\p{In_CJK_Symbols_and_Punctuation}\p{Punctuation}\p{White_Space}\p{In_Halfwidth_and_Fullwidth_Forms}]+$/) && (!$opts[:"fullwidth-english-proper"] || !clsexpr.include?("固有名詞"))
end

def check_containing_fullwidth_english base, clsexpr
  $opts[:"exclude-containing-fullwidth-english"] && base =~ /\p{In_Halfwidth_and_Fullwidth_Forms}/
end