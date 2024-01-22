# frozen_string_literal: true

require './_plugins/jekyll-topic-filter'
require './_plugins/gtn'


def generate_topic_feeds(site)

  # ro-crate-metadata.json
  TopicFilter.list_topics(site).each do |topic|
    feed_path = File.join(site.dest, 'topics', topic, 'feed.xml')
    puts feed_path

    topic_pages = site.pages
      .select { |x| x.path =~ /^\.?\/?topics\/#{topic}/ }
      .select { |x| x.path =~ /(tutorial.md|slides.html|faqs\/.*.md)/  }
      .reject { |x| x.path =~ /index.md/ }
      .reject { |x| x.path =~ /slides-plain.html/ }
      .sort_by { |page| Gtn::PublicationTimes.obtain_time(page.path) }
      .reverse

    if topic_pages.empty?
      puts "No pages for #{topic}"
      next
    else
      puts "Found #{topic_pages.length} pages for #{topic}"
      p topic_pages.map { |x| x.path }
    end

    builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        # Set stylesheet
      xml.feed(xmlns: "http://www.w3.org/2005/Atom") {
        # Set generator also needs a URI attribute
        xml.generator("Jekyll", uri: "https://jekyllrb.com/")
        xml.link(href: "#{site.config['url']}#{site.baseurl}/topics/#{topic}/feed.xml", rel: "self")
        xml.updated(Gtn::PublicationTimes.obtain_time(topic_pages.first.path).to_s)
        xml.id("#{site.config['url']}#{site.baseurl}/topics/#{topic}/feed.xml")
        xml.title("Galaxy Training Network - #{topic}")
        xml.subtitle("Recently updated tutorials, slides, and FAQs in the #{topic} topic")

        topic_pages.each do |page|
          if page.path =~ /faqs\/.*.md/
            page_type = 'faq'
          else
            page_type = page.path.split('/').last.split('.').first
          end

          xml.entry {
            xml.title(page.data['title'])
            xml.link(href: "#{site.config['url']}#{site.baseurl}#{page.url.gsub('slides-plain.html', 'slides.html')}")
            xml.id("#{site.config['url']}#{site.baseurl}#{page.url.gsub('slides-plain.html', 'slides.html')}")
            xml.published(page.date.to_s)
            xml.updated(Gtn::ModificationTimes.obtain_time(page.path).to_s)
            xml.path(page.path)
            xml.category(term: "new #{page_type}")
            # xml.content(page.content, type: "html")
            # xml.summary(page.excerpt)
            xml.author {
              xml.name(Gtn::Contributors.get_authors(page.data)
                .map{|c| Gtn::Contributors.fetch_name(site, c)}
                .join(', '))
            }
          }
        end

      }
    end

    # The builder won't let you add a processing instruction, so we have to
    # serialise it to a string and then parse it again. Ridiculous.
    finalised = Nokogiri::XML builder.to_xml
    pi = Nokogiri::XML::ProcessingInstruction.new(
      finalised, "xml-stylesheet",
      %Q(type="text/xml" href="#{site.config['url']}#{site.baseurl}/feed.xslt.xml")
    )
    finalised.root.add_previous_sibling pi
    File.open(feed_path, "w") { |f| f.write(finalised.to_xml) }
  end

  nil
end

# Basically like `PageWithoutAFile`
Jekyll::Hooks.register :site, :post_write do |site|
  generate_topic_feeds(site)
end
