chef_windows_installed_programs
===============================

This ruby script extracts the installed software list, compares with metadata of available http server and creates cookbook which can be applied on destination node.

Pre-requisites : 
  1. Chef-clinet needs to be installed on workstation i.e. from which this script will be fired
  2. knife should be configured with the chef server on workstation
  3. Source machine configuration : please refer below given section 
  4. Metadata.json : JSON file describing available programs in the arsenal of http server to be used as source for installers.


installed_programs.rb : 
purpose : The script file which does the job.

Params : 
  1. source machine : ip or machine name of a windows machine from which list of installed programs has to be fetched.
  2. user name : name of user with admin privileges.
  3. password
  4. cookbook name : desired name for cookbook which will be generated
  5. cookbook path : the script should be run in the base folder of chef repository i.e. cookbook folder should be present at . or else path for cookbook should be given as this param.


usage : 

      ruby installed_programs.rb 172.86.60.52 admin admin my_cookbook


Source Machine configuration - Source machine i.e. machine from which list of installed programs to be fetched should have following settings :
  1. firewall should be enabled and started
  2. Windows Remote Management service should be enabled and started. Use follwing command to check state of winrm : winrm quickconfig -q
  3. There should be exception in firewall for Windows Remote Management service, in in-bound and out-bound both. Most probably in-bound exception will be in-place. Create new out-bound exception, it should be for program C:\windows\system32\svcshost
  4. In winrm cofiguration following settings should be true : config > service > AllowUnencrypted and config > service > Auth > basic. Restart the machine and run following commands to achive this : 
      
      winrm set winrm/config/service @{AllowUnencrypted="true"}
      winrm set winrm/config/service/Auth @{basic="true"}
      
      
