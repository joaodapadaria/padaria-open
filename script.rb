require_relative 'snp'
require 'pry'
require 'action_view'

def minus_swap(seq)
  case seq
    when 'A'
      return 'T'
    when 'T'
      return 'A'
    when 'C'
      return 'G'
    when 'G'
      return 'C'
    else
      return seq
  end
end

include ActionView::Helpers::SanitizeHelper

config = YAML::load(File.open('config/database.yml'))
ActiveRecord::Base.establish_connection(config)

result = ""
failed = []
count = Snp.count

require 'nokogiri'

binding.pry
#id, rs_number, number_part, full_content
Snp.all.each_with_index do |snp, idx|
  text = '§'
  text += Nokogiri::HTML(snp.full_content).css('.aside-right.col-sm-4')
          .children
          .map(&:text)
          .join('§')
          .gsub(/\s+/, '')

  orientation = if text.index('§Orientationplus').present?
                  true
                elsif text.index('§Orientationminus').present?
                  false
                else
                  'NOT_SET'
                end

  stabilized =  if text.index('§Stabilizedplus').present?
                  true
                elsif text.index('§Stabilizedminus').present?
                  false
                else
                  'NOT_SET'
                end
  
  possible_alleles_regex = /\(([ATCG-]*);([ATCG-]*)\)/
  
  possible_alleles = 'NOT_SET'

  begin
    possible_alleles_pairs = 
      text.scan(possible_alleles_regex)
    possible_alleles = possible_alleles_pairs.flatten.uniq.join(',')
    possible_alleles = 'NOT_SET' if possible_alleles.empty?
  rescue => e
  end

  ambiguous = possible_alleles_pairs.any? do |pair|
                test = pair.map { |allele| minus_swap(allele) }
                
                possible_alleles_pairs.any? do |other|
                  other[0] == test[0] && other[1] == test[1] 
                end
              end rescue 'NOT_SET'
              
  ambiguous = 'NOT_SET' if possible_alleles_pairs.empty?

  reference = 'NOT_SET'
  
  begin
    reference_index = text.index('§Reference') + '§Reference'.length
    reference = text[reference_index..text[reference_index..-1].index('§') + reference_index - 1].strip
  rescue => e
  end

  gene = 'NOT_SET'

  begin
    gene_index = text.rindex('§Gene') + '§Gene'.length
    gene = text[gene_index..text[gene_index..-1].index('§') + gene_index - 1].strip
  rescue => e
  end

  line = "#{snp.rs_number};#{orientation};#{stabilized};#{ambiguous};#{reference};#{gene};#{possible_alleles}\n"

  File.open("snps.txt", 'a') { |file| file << line }
rescue => e
  binding.pry
  failed << snp.rs_number + " - #{e.message}"
  File.open("failed.txt", 'a') { |file| file << failed.join("\n") }
ensure
  puts "#{idx + 1}/#{count}"
end

