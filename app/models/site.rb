require 'rubygems'
require 'json'
class Site < ActiveRecord::Base
	
	has_many :images
	has_many :participants
	validates_presence_of :name
	validates_uniqueness_of :name

	# reads sites directory to find all sites, whether they have records or not
	def self.all
		sitepaths = []
		dirs = Dir.new('public/sites')
		dirs.each do |dir|
			sitepaths << dir if dir[-6..-1] != '_thumb' && dir[0..0] != '.' 
		end
		sites = []
		sitepaths.each do |sitename|
			images = self.imagenames_from_dir(sitename)
			sites << [sitename,images.length]
		end
		sites
	end

	# creates records for any new sites in the Sites directory
	def self.import
		self.all.each do |site|
			# unless it already exists
			unless Site.find_by_name(site[0])
				s = Site.new({ :name => site[0] })
				s.save
			end
		end
	end

	# scans directory for images and imports them 
	# but does not generate thumbnails ... that might lead to thousands generating at once
	
	def import_images
          # collate all .jpgs from each chosen site folder
          path = RAILS_ROOT+'/public/sites/'+self.name
	  json = File.read(path + "/" + "index.json") 
	  metadata = JSON.parse(json)
          metadata.each do |image, image_metadata|
            next unless image[-3..-1] && image[-3..-1].downcase == 'jpg'
            path = image_metadata["url"] || "sites/#{name}/#{image}"
            i = Image.new({
              :path => path,
              :filename => image.split('/').last,
              :site_id => self.id, 
              :lat => image_metadata["lat"],
              :lon => image_metadata["lon"], 
              :mgrs =>image_metadata["mgrs"],
              :collection => image_metadata["collection"],
              :captured_at => image_metadata["captured_at"],
              :thumbnail => image_metadata["thumbnail"],
              :box =>image_metadata["box"].to_json
            })
            i.save
          end
  	end
  	
	# returns _num_ images, starting with those with fewest votes
	def least_voted(num)
		Image.find(:all,:conditions => {:site_id => self.id},:order => "hits", :limit => num)
	end

	# returns _num_ images with fewer than _threshold_ votes, starting with those with fewest votes
	def voted_less_than(threshold,count)
		Image.find(:all,:conditions => ["site_id = ? AND hits < ?",self.id,threshold], :order => "hits", :limit => count)
	end

	def percent_complete
		with_hits = 0
		self.images.each do |image|
			with_hits += 1 if image.hits > 0
		end
                if self.images.length > 0
                  (100*with_hits/self.images.length).to_s+"%"
                else
                  "0%"
                end
	end

	# average score
	def average
		count = self.images.length
		points = 0
		votes = 0
		self.images.each do |image|
			if image.hits > 0
				#puts image.points.to_s + ' of ' + image.hits.to_s
				votes += image.hits
				points += image.points
			end
		end
		votes = 0.00001 if votes == 0
		(10.00*points/votes).to_s.to(3)
	end

	def average_votes
		votes = 0
		self.images.each do |image|
			votes += image.hits
		end
		(10.00*votes/self.images.length).to_s.to(4)
	end

	def path
		'/public/sites/'+self.name
	end

	def unique_participant(key)
            p = Participant.find_by_key(key,:conditions => {:site_id => self.id})
            unless p
              p = Participant.new(:key => key,:site_id => self.id)
              p.save
            end
            p
	end

	def vote_bars
		bars = [0]
		self.images.each do |image|
			bars[image.hits] = 0 if bars[image.hits] == nil
			bars[image.hits] += 1
		end
		0..bars.length do |i|
			bars[i] = 0 unless bars[i]
		end
		bars[0..10] #self.average_votes]
	end

	def self.imagenames_from_dir(dirname)
		Dir.glob(RAILS_ROOT+'/public/sites/'+dirname+'/*.jpg')
	end

	def self.get(site)
		dir = Dir.new(RAILS_ROOT+'/public/sites/'+site)
		dir.first
	end

end
