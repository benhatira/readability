#require 'rubygems'
require 'hpricot'
require 'open-uri'
#require 'iconv'
class Hpricot::Doc
    def removeScripts
        self.search("script").remove
    end
    def getArticleTitle

        curTitle = ""
        origTitle = ""
        curTitle = origTitle = self.search("title").inner_text#.squeeze(' ')            
        hOnes = ""
        puts curTitle
        if curTitle.match(/ [\|\-] /)
            curTitle = origTitle.gsub(/(.*)[\|\-] .*/i,'\1') 
            puts curTitle       
            curTitle = origTitle.gsub(/[^\|\-]*[\|\-](.*)/i,'\1') if(curTitle.length > 150 || curTitle.length < 15) 
            puts curTitle.split(' ').length
        elsif(curTitle.match(': '))
            curTitle = origTitle.gsub(/.*:(.*)/i, '\1')
          
            curTitle = origTitle.gsub(/[^:]*[:](.*)/i,'\1') if(curTitle.length > 150 || curTitle.length < 15) 
            puts curTitle
        elsif(curTitle.length > 150 || curTitle.length < 15)
            hOnes = self.search('h1')
            curTitle = hOnes[0].inner_text if(hOnes.length == 1)
            puts curTitle
        end

        curTitle = curTitle.squeeze(' ')
        #curTitle = origTitle if(curTitle.split(' ').length <= 4) 
        return curTitle
    end
=begin
    def grabEmbed(base_url)

       self.search('embed').each do |embed|
         url =  embed.attributes['src']
         return url
       end
     end
=end  
=begin
    def prepDocument
        var frames = self.search('frame')
        if frames.length > 0
            bestFrame = nil
            bestFrameSize = 0 #    /* The frame to try to run readability upon. Must be on same domain. */
            biggestFrameSize = 0#; /* Used for the error message. Can be on any domain. */
            frames.each do |frame|
                frameSize = frame.offsetWidth + frame.offsetHeight
                canAccessFrame = false
                try {
                    var frameBody = frames[frameIndex].contentWindow.document.body;
                    canAccessFrame = true;
                }
                catch(eFrames) {
                    dbg(eFrames);
                }

                if(frameSize > biggestFrameSize) {
                    biggestFrameSize         = frameSize;
                    readability.biggestFrame = frames[frameIndex];
                }
              
                if(canAccessFrame && frameSize > bestFrameSize)
                {
                    readability.frameHack = true;
  
                    bestFrame = frames[frameIndex];
                    bestFrameSize = frameSize;
                }
            }

            if(bestFrame)
            {
                var newBody = document.createElement('body');
                newBody.innerHTML = bestFrame.contentWindow.document.body.innerHTML;
                newBody.style.overflow = 'scroll';
                document.body = newBody;
              
                var frameset = document.getElementsByTagName('frameset')[0];
                if(frameset) {
                    frameset.parentNode.removeChild(frameset); }
            }
        end
    #    /* Remove all style tags in head (not doing this on IE) - TODO: Why not? */
        self.search("style").remove
    #   /* Turn all double br's into p's */
    #    /* Note, this is pretty costly as far as processing goes. Maybe optimize later. */
     #   document.body.innerHTML = document.body.innerHTML.replace(readability.regexps.replaceBrs, '</p><p>').replace(readability.regexps.replaceFonts, '<$1span>');
    end
=end
  end

  class Hpricot::Elem
    attr_accessor :contentScore, :initialized
  
    REGEXPS = {
        :unlikelyCandidates =>    /combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter/i,
        :okMaybeItsACandidate =>  /and|article|body|column|main|shadow/i,
        :positive =>              /article|body|content|entry|hentry|main|text|blog|story/i,#|page|pagination|post
        :negative =>              /combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget/i,
        :extraneous =>            /print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single/i,
        :divToPElements =>        /<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i,
        :replaceBrs =>            /(<br[^>]*>[ \n\r\t]*){2,}/i,
        :replaceFonts =>          /<(\/?)font[^>]*>/i,
        :trim =>                  /^\s+|\s+$/,
        :normalize =>             /\s{2,}/,
        :killBreaks =>            /(<br\s*\/?>(\s|&nbsp;?)*){1,}/,
        :videos =>                /http:\/\/(www\.)?(youtube|vimeo)\.com/i,
        :skipFootnoteLink =>      /^\s*(\[?[a-z0-9]{1,2}\]?|^|edit|citation needed)\s*$/i,
        :nextLink =>              /(next|weiter|continue|>([^\|]|$)|Â»([^\|]|$))/i, # Match: next, continue, >, >>, Â» but not >|, Â»| as those usually mean last.
        :prevLink =>              /(prev|earl|old|new|<|Â«)/i
    }
    def self.getregexps
      REGEXPS
    end
    def getClassWeight
      #  if !readability.flagIsActive(readability.FLAG_WEIGHT_CLASSES)) {
      #      return 0;
      #  end
        weight = 0

        # Look for a special classname */
        if self.attributes['class']
            if self.attributes['class'].match(REGEXPS[:negative]) 
                weight -= 25
            end
            if self.attributes['class'].match(REGEXPS[:positive])
                weight += 25
            end
        end

        # Look for a special ID */
        if self.attributes['id']
            if self.attributes['id'].match(REGEXPS[:negative])
                weight -= 25
            end
            if self.attributes['id'].match(REGEXPS[:positive])
                weight += 25
            end
        end
        return weight
    end

    def initializeNode 
        @initialized = true
        @contentScore = 0
        case self.name
        when 'div'
            @contentScore += 5
        when 'pre' , 'td' , 'blockquote'
            @contentScore += 3
        when 'address' , 'ol' , 'ul' , 'dl' , 'dd' , 'dt' , 'li' , 'form'
            @contentScore -= 3
        when 'h1' , 'h2' , 'h3' , 'h4' , 'h5' , 'h6' , 'th'
            @contentScore -= 5
        end
        @contentScore += self.getClassWeight
    end
    def getLinkDensity 
        links      = self.search("a")
        textLength = self.inner_content.length
        linkLength = 0
        links.each do |link|
            linkLength += link.inner_content.length
        end     

        return linkLength / textLength rescue 1
    end  
    def clean(cleartag) 
        self.search(cleartag).each do |tag|
          tag.parent.replace_child(tag,'')
          puts "remove #{tag.name} is #{tag.inner_text}"
        end
   #     var isEmbed    = (tag === 'object' || tag === 'embed');
=begin      
        for (var y=targetList.length-1; y >= 0; y-=1) {
            /* Allow youtube and vimeo videos through as people usually want to see those. */
            if(isEmbed) {
                var attributeValues = "";
                for (var i=0, il=targetList[y].attributes.length; i < il; i+=1) {
                    attributeValues += targetList[y].attributes[i].value + '|';
                }
              
                /* First, check the elements attributes to see if any of them contain youtube or vimeo */
                if (attributeValues.search(readability.regexps.videos) !== -1) {
                    continue;
                }

                /* Then check the elements inside this element for the same. */
                if (targetList[y].innerHTML.search(readability.regexps.videos) !== -1) {
                    continue;
                }
              
            }

            targetList[y].parentNode.removeChild(targetList[y]);
        }
=end
    end
  
    def inner_content
      return self.inner_text.squeeze(' ').gsub(/\n|\r|\t/,'')
    end
    def cleanConditionally(cleartag) 
        tagsList      = self.search(cleartag)
        curTagsLength = tagsList.length
        tagsList.each do |tag|
         #   puts tag.inner_text if tag.name == "div"
         #   p tag
            weight = tag.getClassWeight
            contentScore = (tag.initialized) ? tag.contentScore : 0

            if (weight+contentScore) < 0
                tag.parent.replace_child(tag,'')
            else
                p      = tag.search("p").length
                img    = tag.search("img").length
                li     = tag.search("li").length-100
                input  = tag.search("input").length

                embedCount = 0
                embeds     = tag.search("embed")
                embeds.each do |embed|
                   if embed.attributes['src'].match(REGEXPS[:videos]) 
                      embedCount+=1 
                   end
                end

                linkDensity   = tag.getLinkDensity
                contentLength = tag.inner_content.length
                toRemove      = false

                if img > p and contentLength < 25
                    puts tag.name + tag.attributes['id'] + tag.attributes['class'] +' img>p'
                     #puts tag.inner_html
                    toRemove = true
                elsif li > p and cleartag != "ul" && cleartag != "ol"
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] +' li>p'
                    toRemove = true
                elsif input > (p/3).floor and contentLength < 25
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] + ' input>p/3'
                    toRemove = true 
                elsif contentLength < 25 and (img == 0 or img > 2) 
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] +' content < 25'
                    toRemove = true
                elsif weight < 25 and linkDensity > 0.2
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] + ' weight < 25'
                    toRemove = true
                elsif weight >= 25 and linkDensity > 0.5
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] + ' wfight > 25'
                    toRemove = true
                elsif (embedCount == 1 and contentLength < 75) or embedCount > 1
                  puts tag.name + tag.attributes['id'] + tag.attributes['class'] + ' embed'
                    toRemove = true
                elsif (tag.name == "table" or tag.name == "ul") and contentLength/tag.children.length < 50
                  puts  tag.name + ',' + tag.attributes['id'] + ',' + tag.children.length.to_s + ','+  contentLength.to_s + ',' + tag.inner_content
                  #puts  tag.inner_content
                   toRemove = true  
                end
                tag.parent.replace_child(tag,'') if toRemove 
            end
        end
    end
    def cleanHeaders
        for i in 1..3 do
            headers = self.search('h' + i.to_s);
            headers.each do |head|
                head.parent.replace_child(head,'') if (head.getClassWeight < 0 || head.getLinkDensity > 0.33)     
            end
        end
    end
    
    def grabImage(base_url)
      #best_image_url = nil
      #large_size = 0
       self.search('img').each do |img|
            url =  img.attributes['src']
#            puts url
            next if url.match(/\.gif$/)
            if(base_url.match(/pantip\.com/))
              url = base_url.gsub(/\.html/,'-0.jpg')
            else
              next unless url.match(/http:\/\//)
            end
           # puts url
            io = open(url) rescue next
            if io.content_type =~ /image\/(jpeg|jpg|png)/
              #puts "io type =#{io.content_type}"
              dimension = `identify -format "%w %h" #{url}`
              size = dimension.split(' ')
              next if size[0].to_i < 150 or size[1].to_i < 150
              return url
              #def io.original_filename; base_uri.path.split('/').last; end
              #io.original_filename.downcase =~ /(jpeg|jpg|png)/ ? io : nil
   #           size_indicate = size[0].to_i + size[1].to_i
   #          if large_size < size_indicate
   #              large_size = size_indicate
   #            best_image_url = url
  #           end 
            end
          end
   #     return best_image_url
          return nil
       rescue  # catch url errors with validations instead of exceptions (Errno::ENOENT, OpenURI::HTTPError, etc...)
         raise
         return nil
       end
       
       def grabEmbed(base_url)

          self.search('embed').each do |embed|
            url =  embed.attributes['src']
            return url
          end
          return nil
        end
       
      def prepArticle(base_url)
          #self.cleanStyles(articleContent);
          #readability.killBreaks(articleContent);

         # /* Clean out junk from the article content */
          self.cleanConditionally("form")
          self.clean("select")
          self.clean("object")
          self.clean("h1")
          self.clean("big")

    #       * If there is only one h2, they are probably using it
    #       * as a header and not a subheader, so remove it since we already have a header.

          self.clean( "h2") if self.search('h2').length == 1 


          self.clean("iframe")

  #todo clear header
          self.cleanHeaders
      #    /* Do these last as the previous stuff may have removed junk that will affect these */
          self.cleanConditionally("table")
          self.cleanConditionally("ul")
          #puts "============debug div clean============"
          if(base_url.match(/dek-d\.com/i))
              self.search('div#rightpanel').remove
              self.search('div#boardowner').remove
          end
          self.cleanConditionally("div")
           #puts "============end  debug div clean============"
           
        #  /* Remove extra paragraphs */
          self.search('p').each do |p|
              imgCount    = p.search('img').length
              embedCount  = p.search('embed').length
              objectCount = p.search('object').length

              p.parent.replace_child(p,'') if imgCount == 0 and embedCount == 0 and objectCount == 0 and self.inner_content == ''
          end
=begin
          try {
              articleContent.innerHTML = articleContent.innerHTML.replace(/<br[^>]*>\s*<p/gi, '<p');      
          }
          catch (e) {
              dbg("Cleaning innerHTML of breaks failed. This is an IE strict-block-elements bug. Ignoring.: " + e);
          }
=end
      end
  end

=begin
siblingScoreThreshold = [ 10, topCandidate.contentScore * 0.2 ].max
siblingNodes          = topCandidate.parentNode.children

siblingNodes.each do |siblingNode|
    append  = false
    next unless siblingNode

#    dbg("Looking at sibling node: " + siblingNode + " (" + siblingNode.className + ":" + siblingNode.id + ")" + ((typeof siblingNode.readability !== 'undefined') ? (" with score " + siblingNode.readability.contentScore) : ''));
#    dbg("Sibling has score " + (siblingNode.readability ? siblingNode.readability.contentScore : 'Unknown'));

    append = true if siblingNode == topCandidate
        
    
    contentBonus = 0
#    /* Give a bonus if sibling nodes and top candidates have the example same classname */
    if siblingNode.attributes['class'] == topCandidate.attributes['class'] and topCandidate..attributes['class'] != ""
        contentBonus += topCandidate.contentScore * 0.2
    

    append = true if siblingNode.initialized and (siblingNode.contentScore+contentBonus) >= siblingScoreThreshold
        
    
    if siblingNode.name == "p"
        linkDensity = siblingNode.getLinkDensity
        nodeContent = siblingNode.inner_text
        nodeLength  = nodeContent.length
        append = true if nodeLength > 80 and linkDensity < 0.25
        append = true if nodeLength < 80 and linkDensity == 0 and nodeContent.match(/\.( |$)/)
    end

    if append 
        nodeToAppend = nill
        if siblingNode.name != "div" and siblingNode.name != "p"
#            /* We have a node that isn't a common block level element, like a form or td tag. Turn it into a div so it doesn't get filtered out later by accident. */
            nodeToAppend = document.createElement("DIV");
                nodeToAppend.id = siblingNode.id;
                nodeToAppend.innerHTML = siblingNode.innerHTML;

        } else {
            nodeToAppend = siblingNode;
            s-=1;
            sl-=1;
        }

        articleContent.appendChild(nodeToAppend);
    }
} 
=end

