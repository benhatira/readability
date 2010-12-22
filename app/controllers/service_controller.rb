class ServiceController < ApplicationController
  include ActionView::Helpers::TextHelper
  require "hpricot_integrated"
  def json
    url = params[:url]
    unless @page = Page.find_by_url(url)
      json = readability_digest(params[:url])
      @page = Page.create(json)
    end
    @page.content = truncate(@page.content , :length => 120, :omission => ' ...')
    render :text => @page.to_json#{}"<p>#{json[:title]}</p><p>#{json[:content]}</p><p>#{json[:image]}</p><p>#{json[:embed]}</p>", :layout => false
  end
  
  def readability_digest(url)
    content = `curl #{url}`
    if content.match(/charset=tis-620/i)
      digest = Iconv.conv('UTF-8//ignore', 'tis-620', content)
    elsif content.match(/charset=windows-874/i)
      digest = Iconv.conv('UTF-8//ignore', 'tis-620', content)
    else
      digest = content
    end

    hcontent  = Hpricot(digest) 
    node = nil
    articleTitle = hcontent.getArticleTitle 
    hcontent.removeScripts
    #get content section
    content_body =  hcontent.at("body").innerHTML
    nodesToScore = Array.new
    hcontent.at("body").search('*') do |node|
      next unless node.elem?
      unlikelyMatchString = node.name + node.attributes['id']
      if  unlikelyMatchString.match(Hpricot::Elem.getregexps[:unlikelyCandidates]) and !unlikelyMatchString.match(Hpricot::Elem.getregexps[:okMaybeItsACandidate]) and node.name != "body"
          node.parent.replace_child(node,'')
          next
      end
      if node.name == "p" or node.name == "td" or node.name == "pre"
          nodesToScore << node;
      end
      if node.name == "div"
          if !node.innerHTML.match(Hpricot::Elem.getregexps[:divToPElements]) 
              begin
                  nodesToScore << node
              rescue Exception => e
                  puts "Could not alter div to p, probably an IE restriction, reverting back to div.: " + e 
              end
          else
          end
       end
    end   
    candidates = Array.new
    nodesToScore.each do |node|
      parentNode = node.parent
      grandParentNode = parentNode ? parentNode.parent : nil
      innerText = node.inner_content
      next unless parentNode
      next if innerText.length < 25
      #if not initialize
      unless parentNode.initialized
        parentNode.initializeNode 
        candidates << parentNode
      end
      # not nil and not initialize
      if grandParentNode and !grandParentNode.initialized
        grandParentNode.initializeNode 
        candidates << grandParentNode
      end
      contentScore = 0
    # Add a point for the paragraph itself as a base. 
      contentScore +=1
      #contentScore += [ node.search('<br>').length , 5 ].min
      # For every 100 characters in this paragraph, add another point. Up to 3 points. */
      contentScore += [ (innerText.length / 100).floor , 5 ].min
      puts parentNode.contentScore
      # Add the score to the parent. The grandparent gets half. */
      parentNode.contentScore += contentScore
        
      puts parentNode.name + ' (' + parentNode.attributes['class'] + ',' + parentNode.attributes['id'] + ') ' + parentNode.contentScore.to_s + ' ' + parentNode.inner_content
      if grandParentNode 
          puts 'grandparent + score ' + grandParentNode.name + ' ' + (contentScore/2).to_s + ' ' + grandParentNode.inner_content
          grandParentNode.contentScore += contentScore/2            
      end
    end
    topCandidate = nil
    candidates.each do |candidate|
    #    /**
    #     * Scale the final candidates score based on link density. Good content should have a
    #     * relatively small link density (5% or less) and be mostly unaffected by this operation.
    #    **/
        puts candidate.name + ' ' + candidate.contentScore.to_s + ' ' + candidate.inner_content if candidate.contentScore >5
        candidate.contentScore = candidate.contentScore * (1-candidate.getLinkDensity)
        puts candidate.name + ' ' + candidate.contentScore.to_s + ' ' + candidate.inner_content if candidate.contentScore >5
        if !topCandidate or candidate.contentScore > topCandidate.contentScore
            topCandidate = candidate
        end
    end
    screenshot = topCandidate.grabImage(url)
    screenshot = topCandidate.parent.grabImage(url) unless screenshot
    puts topCandidate.inner_html
    embed = hcontent.at("body").grabEmbed(url)
    topCandidate.prepArticle
    puts topCandidate.name + ' ' + topCandidate.contentScore.to_s + ' ' + ' ' + topCandidate.inner_content.length.to_s + ' ' + articleTitle 
    puts topCandidate.inner_content#content#Iconv.conv('UTF-8//ignore', 'tis-620', topCandidate.inner_text.gsub(/\s+/,' '))
    return {:url => url ,:title => articleTitle , :content => topCandidate.inner_content , :image => screenshot , :embed => embed}
  rescue
    return {:url => "" , :title => "" , :content => "" , :image => "" , :embed => ""}
  end
end
