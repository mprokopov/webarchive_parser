# -*- coding: utf-8 -*-
# Usage: ruby parse.rb start_url site_url
# load the Family guy's home page
require 'rubygems'
require 'hpricot' # need hpricot and open-uri
require "open-uri"
require 'fileutils'
require 'iconv'

SITE_URL = "it-service.net.ua"
DEPTH = 5
SERVER = "replay.web.archive.org"
@@visited_array = []

 def log(str)
   File.open("log.txt","w+"){ |log|   
     log << "#{str}\r\n" 
   }
 end

 def url2path(url)
   url = url.gsub(/http:\/\/#{SERVER}\/.*\/http:\/\/www.it-service.net.ua(.*)/,"\\1")  
   # url.slice!(0)
   url = url.gsub(/^\//,'')  # уберем передний слеш
   return url
 end

 ## забирает файл по url и сохраняет по такому же пути
 def fetch_file(url)
   return if @@visited_array.include?(url)
   path = url2path(url)
   FileUtils.mkdir_p(path.gsub(/(.*)\/(.*)$/,"\\1"))
     begin
     File.open(path,"w"){|f|
       f << open(url).read
     } unless File.exists?(path)
     rescue 
       printf "#{$!} url: #{url} path: #{path}\n"

       begin
         File.delete(path)
       rescue
       end
     end  
     @@visited_array << url
     # дебаг
     log(url)
     return path
 end

def change_backlinks(doc)
  (doc/"*[@href*=#{SERVER}]").each{|a|
    a[:href] = a[:href].gsub(/http:\/\/#{SERVER}\/.*\/(http:\/\/)/,"\\1")
  }

  (doc/"*[@src*=#{SERVER}]").each{|a|
    a[:src] = a[:src].gsub(/http:\/\/#{SERVER}\/.*\/(http:\/\/)/,"\\1")
  }

  doc2 = doc.html.gsub(/http:\/\/#{SERVER}\/.*\/(http:\/\/)/,"\\1")
  doc2 = doc.html
  doc2.gsub!(/(\<\/html\>).*/m,"\\1")
  return doc2
end

def fetch_images(doc)
  (doc/"img[@src*=#{@site_url}]").each{|img|
    fetch_file(img[:src])
  }
end
def fetch_css(doc)
  (doc/"link[@href*=#{@site_url}]").each{|link|
    css_file = fetch_file(link[:href])
    # change_backlinks(open(link[:href]))
  }
end

def parse_page(url,depth)
  begin
    return unless depth < DEPTH && !@@visited_array.include?(url)
    printf "depth: #{depth} url:#{url}\n"
    
  page = open(url).read.gsub(/BEGIN WAYBACK TOOLBAR INSERT .* END WAYBACK TOOLBAR INSERT/m,"")
  doc_page = Hpricot(page)
  (doc_page/"base").remove
  fetch_images(doc_page)
  fetch_css(doc_page)
  
  # make directory
  path = url2path(url)
  FileUtils.mkdir_p(path.gsub(/(.*)\/(.*)$/,"\\1"))
  path+="index.html" if path.match /.*\/.+$/
  
  begin
  File.open(path,"w:cp1251"){|f|
     @@visited_array << url # что бы не заходить повторно
     # дебаг
     # log(url)
      threads = []
      (doc_page/"a[@href*=#{SITE_URL}]").each{|link|
        threads << Thread.new(link) do |link2|
            parse_page(link2[:href],depth+1) if link2[:href].match(/#{SERVER}/)
            printf "-- thread --\n"
        end
      }
    threads.each {|thr| thr.join }  

    f << Iconv.conv('CP1251','UTF8',change_backlinks(doc_page))
    printf "url: #{url} path: #{path} - success\n"
  } unless File.exists?(path)
  rescue 
    print $!
  end
  rescue
    print $!
  end

end

f2 = File.new("index.html","w")
# <!-- BEGIN WAYBACK TOOLBAR INSERT -->
# <!-- END WAYBACK TOOLBAR INSERT -->
# f1 = File.open("test.html").read.gsub(/BEGIN WAYBACK TOOLBAR INSERT .* END WAYBACK TOOLBAR INSERT/m,"")

url = ARGV[0]
url ||= "http://replay.web.archive.org/20070225220836/http://it-service.net.ua/"

@site_url = ARGV[1]
@site_url ||= "it-service.net.ua"

f1 = open(url).read.gsub(/BEGIN WAYBACK TOOLBAR INSERT .* END WAYBACK TOOLBAR INSERT/m,"")
# http://replay.waybackmachine.org/20070225220836/http://it-service.net.ua/
# http://replay.web.archive.org/20070224025044/http://www.it-service.net.ua/component/option,com_frontpage/Itemid,1/
indoc = Hpricot(f1)


# change the CSS class on list element ul

# заменить все href http://replay.waybackmachine.org/20070225220836im_/http://www.it-service.net.ua/

# (doc/"ul.site-nav").set("class", "new-site-nav")

# remove the header
# (doc/"#header").remove

# doc.search("//comment()")

 (indoc/"base").remove
 (indoc/"a[@href*=#{@site_url}]").each_with_index{ |a,index|
     parse_page(a[:href],1) # depth 1
 }

# встречаем изображение - загружаем и сохраняем в файловой структуре

 fetch_images(indoc)
 clean_html = change_backlinks(indoc)

 f2 << Iconv.conv('CP1251','UTF8',clean_html) 
 f2.close
