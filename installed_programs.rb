#!usr/bin/env ruby

#requirement : Metadata.json to be present in the same folder

source_machine = ARGV[0]
source_user_name =  ARGV[1]
source_user_pass =  ARGV[2]
cookbook_name = ARGV[3]
cookbook_path = ARGV[4]

# TODO - 1. system_component - consider that 2. wget metadata.json from http server  3. error handling 4.force version : even if version is diff include the package with available version

require 'winrm'
endpoint = "http://" + source_machine + ":5985/wsman"

$package_list = Hash.new
$winrm = WinRM::WinRMWebService.new(endpoint, :plaintext, :user => source_user_name, :pass => source_user_pass, :disable_sspi => true)

def chek_packages_in_registry(reg)
	reg = reg.strip

	$winrm.cmd('REG QUERY "' + reg + '"') do |key|
		if (key.nil?)	
			next	
		end    
		key = key.strip
	    if (key.empty?) 
	    	next
	    end 
	    if (reg == key)
	    	next
	    end

		$display_name = ""
		$system_component = ""
		$version = ""

		key_array = key.split("\n")
		key_array.each do |sub_key|
      
			sub_key = sub_key.strip
			key_entry_array = sub_key.split("    ")

			key_entry_array.each do |key_entry|
			    if (key_entry_array.length < 3)
					next
   				end 
    			if (key_entry_array[0] == "DisplayName")
					$display_name = key_entry_array[2]
				end
   			    if (key_entry_array[0] == "SystemComponent")
   			    	$system_component = key_entry_array[2] 
   				end
				if (key_entry_array[0] == "DisplayVersion")
					#puts "in version " + key_entry_array[2]					
					$version = key_entry_array[2]
				end
			end
	
    	end

		if (($display_name.nil?) or ($display_name.empty?))
			next
	    end

		kb_pattern = /(KB\d{6,})/
	    kb_pattern_result = kb_pattern =~ $display_name
   	    if ((!$display_name.empty?) and ($display_name != "?") and (kb_pattern_result.nil?) and ($system_component != "0x1"))
			if (!$package_list.include?($display_name))
				$package_list[$display_name] = $version 
			end
   	    end
	end
end

def process_reg_keys(reg_keys)
	$winrm.cmd('REG QUERY "'+ reg_keys +'"') do |key|	
	  if (key.nil?)
	    next
	  end
	  key = key.strip
	  if (key.empty?) 
    	next
	  end 
	  key_array = key.split("\n")
	  if (key_array.length > 0)
	    key_array.each do |reg|
	      chek_packages_in_registry(reg)
	    end
	  end
	end
end

process_reg_keys('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
process_reg_keys('HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
process_reg_keys('HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')


puts "source machine pacakge list : " + $package_list.to_s

#get available resources on server

require 'json'

#read SourceInfo.json
source_json = File.open('Metadata.json', 'r').read
source_list = JSON.parse(source_json)
puts "metadata pacakges from http server" + source_list.to_s

def create_recipe_for_package(package, hash)
	recipe_str = 'windows_package "' + package + '" do' + "\n" + '  source "' + hash["SourceUrl"]  + '" ' + "\n" + '  action :install'  + "\n" + "end"
end

not_available_metadata = Hash.new
different_version_available = Hash.new
available_pacakge_list = Hash.new

#compare package list and source list

recipe = ''

$package_list.each do |package, version|
	if (source_list.include?(package))
		metadata_package = source_list[package]
		if (metadata_package["version"] == version)
			#include recipe for this package
			recipe += create_recipe_for_package(package, metadata_package)
			recipe += "\n\n"
		else
			different_version_available[package] = {"package_version" => version, "Metadata_version" => metadata_package["version"]}
		end
	else
		not_available_metadata[package] = version
	end
end


#create recipe file
File.open('package_recipe.rb', 'w') { |file| file.write(recipe) }



#create a cookbook with given name
if (cookbook_name.empty?)
	#cookbook_name = "cookbook_" + source_machine.to_s + Time.now.strftime("%Y-%m-%d-%H:%M:%S")
	cookbook_name = "cookbook_" + Time.now.strftime("%Y-%m-%d-%H-%M-%S")
end

puts cookbook_name


#path for cookbook folder in current chef repository
if ((cookbook_path.nil?) or (cookbook_path.empty?))
	cookbook_path = "./cookbooks/"
end


`knife cookbook create #{cookbook_name}`

cookbook_name_full = cookbook_path + cookbook_name

#move package_recipe.rb to /home/abhay/chef-server-local-30.27/cookbooks/test/recipes
`cp package_recipe.rb #{cookbook_name_full}/recipes`

#add line to include recipe in default.rb
File.open("#{cookbook_name_full}/recipes/default.rb", 'w') do |file| 
	file.puts "include_recipe '#{cookbook_name}::package_recipe'"
	file.puts "\n\n"
	file.puts "=begin"
	file.puts "NOTE : "
	file.puts "Some packages are not installed due to unavailablity of them on the http server."
	file.puts "You might want to consider updating the http server. Please find the details below: "
	file.puts "packages not available on source server metadata : " + not_available_metadata.to_s
	file.puts "packages available with different version : " + different_version_available.to_s
	file.puts "=end"
end

#delete the test cookbook
#find out the cookbook with given name is already present or not
cookbook_list = `knife cookbook list`
cookbook_array = cookbook_list.split("\n")

if cookbook_array.include?(cookbook_name)
	`knife cookbook delete #{cookbook_name} --yes`
end

#upload new test cookbook
`knife cookbook upload #{cookbook_name}`

