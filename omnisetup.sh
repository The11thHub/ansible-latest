#============================================================================
#
#     (c) Copyright 2019 Micro Focus or one of its affiliates.
#
#     PACKAGE      Data Protector
#     FILE         omnisetup.sh
#     RCS          $Header: /shell/inst/local/omnisetup.sh $Rev$ $Date::                      $:
#
#     DESCRIPTION
#       Data Protector local installation on various Unix platforms.
#
#============================================================================
# USAGE:
#
#   see Usage()
#
#============================================================================

# When the version change is needed, these are the necessary places:
# TAPEBASENAME, TAPEBASENAME2, 
# CheckInstalledVersion function, the current version must be updated in the first 'case'

#Debug="set -x"
Debug=""
$Debug

sh_path=`dirname $0`

PRODUCT="DATA-PROTECTOR"
SUBPRODUCT=""
SW_DEPOT="DP_DEPOT"

# Default is awk, except for SunOS, which uses nawk (see below)
AWK=awk
SmisaDependPackets=""
PegasusDependPackets="smisa netapp netapp_array vmwaregre_agent vepa dellemcunity"
IntegrationPackets="db2 emc informix lotus oracle8 sapdb saphana sap sybase ssea mysql postgresql postgresql_agent mysql_agent"
NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls autodr StoreOnceSoftware vepa vmwaregre_agent"
CorrectPackets="$NonIntegrationPackets $IntegrationPackets $PegasusDependPackets"
VERSION=A.10.91
#VERSION=A.10.91
VERSION_S=`echo $VERSION | $AWK -F"." '{ print $1  "."  $2 "." $3 }'`
VERSION_P=`echo $VERSION | $AWK -F"." '{ print $1 $2 $3 }'`
BDL_VERSION=$2
OldMA=""
NewMA=""

InstalledProductName="Data Protector"

SustainMaintenanceMode=1    # Continue to keep it is maintenance mode after Upgrade.
Old_Version=0               # Variable is used in case of -Uninstall scenario before Upgrade. 
skipOpenFileLimitCheck=0    # Variable is used to skip VerifyOpenFileLimit in case the required IDB service user account does not exist 

#This global variable OB2NOEXEC will be set in case /tmp is mounted with a noexec setting on a Linux system
#If the variable is set, use /var/opt/omni/tmp/omni_tmp for further execution
UNAME=`uname -a`
ARCH=`echo ${UNAME} | $AWK '{print $1}'`

CMUpgrade="No"
CellServer=""
ExistingCellServer=""
# Names of packets that CM and IS configurations contain
HPISComponents="DATA-PROTECTOR.OB2-IS"
HPCMComponents="DATA-PROTECTOR.OB2-CM DATA-PROTECTOR.OB2-DOCS"
HPCMComponents1123="DATA-PROTECTOR.OB2-CM DATA-PROTECTOR.OB2-DOCS"

GPLCoreComponent="OB2-CORE OB2-TS-CORE"
GPLISComponents="OB2-CORE-IS OB2-CFP OB2-TS-CFP OB2-DAP OB2-MAP OB2-NDMPP OB2-CCP OB2-INTEGP OB2-TS-PEGP OB2-DB2P OB2-EMCP OB2-INFP OB2-LOTP OB2-OR8P OB2-SAPDBP OB2-SAPHANAP OB2-SAPP OB2-SYBP OB2-SMISAP OB2-SSEAP OB2-VEPAP OB2-AUTODRP OB2-SODAP OB2-VMWAREGRE-AGENTP OB2-DOCSP OB2-FRAP OB2-JPNP OB2-CHSP OB2-NETAPPP_ARRAY OB2-POSTGRESQLP_AGENT OB2-DELLEMCUNITYP OB2-MYSQLP_AGENT"
GPLCMComponents="$GPLCoreComponent OB2-TS-JRE OB2-TS-CS OB2-CC OB2-TS-AS OB2-WS OB2-JCE-DISPATCHER OB2-CS OB2-DA OB2-MA OB2-DOCS"

ComponentTempFile="/tmp/omni_tmp/DPInstallComponents"

if [ "$SUBPRODUCT" = "AppRM" ]; then #AppRM
  DPOBBundles="APPRM B7878MA T5404A"
else #DP
  DPOBBundles="DATA-PROTECTOR OMNIBACK-II B6951 B6952 B6953 B6954 B6955 B6956 B6957 B6958 B6959 B6960 B6961 B6962 B6963 B6964 B6965 B6966 B6967 B6968 B7020 B7021 B7022 B7023 B7024 B7025 B7026 B7027 B7028 B7029 B7030 B7031 B7033 B7034 B7035 B7036 B7037"
fi

PACKET=packet.Z

TAPEBASENAME="DP_${VERSION_P}_"

# TapePlatforms defines which platforms can be installed from the specified tapefilename.
# format 'SDLabel TapeSuffix CS Client IS'
TapePlatforms="
SD1 OB2-CS-$VERSION_S-1.x86_64.rpm gpl* 0 0 linux_x86_64
SD2 OB2-CORE-IS-$VERSION_S-1.x86_64.rpm 0 *linux* gpl* linux_x86_64
SD3 DATA-PROTECTOR/OMNI-CS/opt/omni/lbin/mmd hp* 0 0 hpux
SD4 DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/lbin/bmsetup 0 All hp* hpux"

TMPClient="/tmp/omnisetup_client"  # pending packets are here, Client must be installed, if exists
TMPIS="/tmp/omnisetup_IS"          # IS must be installed, if exists
TMPCM="/tmp/omnisetup_CM"          # CM must be installed with uninstallation first, if TMPCM exists
ScriptName=""
DefaultScriptName="/opt/omni/bin/UpgradeCheck.pl"
#obsolescence Info
obsolescenceInfo=1
obsolescenceHeader="        OBSOLESCENCE INFORMATION \n     ---------------------------------------------------------------------------"
obsolescenceFooter="     ---------------------------------------------------------------------------"

#set inet port
INET_PORT=""
#set secure data communication and enable audit logs
SEC_DATA_COMM=""
AUDITLOG=""
AUDITLOG_RETENTION=""

if [ -f /etc/opt/omni/server/idb/version.txt ];then
  DB_VERSION_STR_OLD=`$AWK '{sub("HP OpenView OmniBack II +",""); sub("HP( StorageWorks | )Application Recovery Manager +",""); print}' /etc/opt/omni/server/idb/version.txt`
  Old_Version=`echo $DB_VERSION_STR_OLD |awk -F"." '{ print $2 $3 }'`
fi

collectTelemetryData=1
license=""
retAns=""
licenseHeader="        TELEMETRY LICENSE AGREEMENT \n     ---------------------------------------------------------------------------"
licenseFooter="     ---------------------------------------------------------------------------"

#Reporting Variables
RSUSERNAME=""
RSPASSWORD=""
RSREPASSWD=""
RSPORT=""
RSPGUSER=""
RSPGPORT=""
SILENTINSTALL=0
RSPGPASS=""
RSPGGROUP=""
PG_DATA_TMP=/var/opt/omni/tmp
PGOSUSER=""

#variables for Debugging
envSet=""

#constants for idb upgrade
HPDPHOME=/home/hpdp
PGUPGRADEPORT=3612
idbBackupCheck=1

getTelemetryData() {

if [ "$subscriptionValue" = "t" ]; then
    collectTelemetryData=0
    return
fi

#Telemetry Data
telemetryData_CompName="        Enter Company Name[]         :";
telemetryData_ProxyAddr="        Enter Proxy Address[]        :";
telemetryData_ProxyPort="        Enter Proxy Port[]           :";
telemetryData_ProxyUser="        Enter Proxy host Username [] :";
telemetryData_ProxyPass="        Enter Proxy host Password [] :";

#Telemetry Data Values
telemetryValue_CompName="";
telemetryValue_ProxyAddr="";
telemetryValue_ProxyPort="";
telemetryValue_ProxyUser="";
telemetryValue_ProxyPass="";

if [ -f "$PRODBRANDINGCURRENTDIR/telemetry.txt" ]; then
  license=`cat $PRODBRANDINGCURRENTDIR/telemetry.txt`
else
  license="        In order to enable Micro Focus to better serve its Data Protector customers and \n        to enhance Micro Focus\'s ability to provide product improvements, we intend to \n        trigger automatic collection of certain customer usage and performance \n        information. As more specifically described below, at no point will we \n        access or collect any personal information, or any other information \n        contained in any customer\'s Data Protector archive. By not accepting \n        this agreement, you may opt out of any data collection process \n        associated with the update. You may also opt out of the collection \n        program at any time after installation of the update if you so choose.\n        \n        We are committed to preserving the privacy of all users of Micro Focus Data \n        Protector. Please read the following description to understand how Micro Focus \n        will use and protect the information about your backup environment that \n        you may automatically provide to Micro Focus after the update has been \n        completed.\n        \n        What Information We May Collect:\n        We may collect from you certain usage and performance data such as Cell \n        Manager and Client version and patch levels, target backup device \n        configurations, Data Protector Licenses installed, and type and amount \n        of data protected. This information is held on Micro Focus\'s secure server and \n        will be used solely for our internal analytics to help us improve our \n        service to you. \n        \n        Information we do not collect from you: \n        No personal information, such as username, password, IP, host names, \n        subnet mask, VM names, and hypervisor names will be collected or \n        transferred to Micro Focus.\n        \n        How we use the information we collect: \n        The usage and performance information Micro Focus collects will enable us to \n        support, improve and develop Micro Focus Data Protector. In particular, we may \n        use this information to inform you about patches you may need which \n        will improve your support experience. The information we collect will \n        also help us define the roadmap for Data Protector based on the \n        features you use. These activities are essential to improve Micro Focus\'s \n        products and your service. \n        \n        Security and data retention: \n        We employ industry-standard security measures to protect your \n        information from access by unauthorized persons and against unlawful \n        processing, accidental loss, destruction and damage. We will retain \n        your information for a reasonable period of time, after which it will \n        be securely deleted.\n        \n        Please do not hesitate to reach out to our support team at \n        https://www.microfocus.com/support-and-services/\n        information should you have any questions, comments, or concerns about \n        the Update, the data collection process, your ability to opt out, or \n        any other Data Protector issues.\n"
fi

if [ "$collectTelemetryData" -eq 1 ]; then
        printf "\t\t\t$licenseHeader\n"
        printf "$license"
        printf "$licenseFooter\n"
        printf "        I accept the terms in the license agreement [Y/N] : "
        getAnswer
        collectTelemetryData=$?
elif [ "$collectTelemetryData" -eq 2 ]; then
     if [ "${telemetryValue_CompName}" = "" -o "${telemetryValue_ProxyAddr}" = "" -o "${telemetryValue_ProxyPort}" = "" -o "${telemetryValue_ProxyUser}" = "" -o "${telemetryValue_ProxyPass}" = "" ]; then
             printf "        Thanks for accepting to provide telemetry data.\n"
             printf "        Please provide us following information:\n"
     fi
fi

if [ "$collectTelemetryData" -eq 1 -o "$collectTelemetryData" -eq 2 ]; then

        if [ "${telemetryValue_CompName}" = "" ]; then
                printf "${telemetryData_CompName}"
                read telemetryValue_CompName
                while [ 1 ]
                do
               str_len=`echo ${telemetryValue_CompName} | tr -d  "[a-zA-Z0-9\ ]"`
                     if [ ${#telemetryValue_CompName} -lt 2 -o ${#telemetryValue_CompName} -gt 1023 ]; then
                          printf "        Company Name should be between 2 and 1024 characters \n"
                          printf "${telemetryData_CompName}"                          
                          read telemetryValue_CompName
                     elif  [ ${#str_len} -ne 0 ]; then
                    printf "        Company Name can contain only a-zA-Z0-9 characters \n"
                    printf "${telemetryData_CompName}"                          
                          read telemetryValue_CompName
                     else
                          break
                     fi
                done
                
        fi

        if [ "${telemetryValue_ProxyAddr}" = "" ]; then
                printf "${telemetryData_ProxyAddr}"
                read telemetryValue_ProxyAddr
                while [ 1 ]
                do
               str_len=`echo ${telemetryValue_ProxyAddr} | tr -d  "[^a-zA-Z0-9:\/\.\-]"`
               if [ ${#telemetryValue_ProxyAddr} -eq 0 ]; then
                    printf "        Are you sure you wish to skip proxy settings[Y/N] :"
                    getAnswerEx 
                    retAns=$?
                    if [ ${retAns} -eq 1 ]; then
                         break;
                    else
                         printf "${telemetryData_ProxyAddr}"
                         read telemetryValue_ProxyAddr
                    fi
               elif [ ${#str_len} -ne 0 ]; then
                    printf "        Proxy Address should contain only a-zA-Z0-9:/.- characters \n"
                    printf "${telemetryData_ProxyAddr}"                          
                          read telemetryValue_ProxyAddr               
               elif [ ${#telemetryValue_ProxyAddr} -gt 1023 ]; then
                          printf "        Proxy address should be less than 1024 characters \n"                    
                    printf "${telemetryData_ProxyAddr}"                          
                          read telemetryValue_ProxyAddr                                         
               else
                    break
               fi
          done
        fi
        
        if [ ${#telemetryValue_ProxyAddr} -ne 0 ]; then
          if [ "${telemetryValue_ProxyPort}" = "" ]; then
               printf "${telemetryData_ProxyPort}"
               read telemetryValue_ProxyPort
                     while [ 1 ]
                     do
                    str_len=`echo ${telemetryValue_ProxyPort} | tr -d  "[^0-9]"`
                    if [ ${#telemetryValue_ProxyPort} -eq 0 ]; then
                         #telemetryValue_ProxyPort=8088
                         printf "        Are you sure, you wish to skip proxy port[Y/N] :"
                         getAnswerEx 
                         retAns=$?
                         if [ ${retAns} -eq 1 ]; then
                              break;
                         else
                              printf "${telemetryData_ProxyPort}"
                              read telemetryValue_ProxyPort
                         fi
                    elif [ ${#str_len} -ne 0 ]; then
                         printf "        Please enter only numeric characters\n"
                         printf "${telemetryData_ProxyPort}"                          
                               read telemetryValue_ProxyPort                                   
                    elif [ ${#telemetryValue_ProxyPort} -gt 5 ]; then
                         printf "        Proxy port should be less than 6 characters \n"                    
                         printf "${telemetryData_ProxyPort}"                          
                         read telemetryValue_ProxyPort                                         
                    else
                         break
                    fi
               done
          fi

          if [ "${telemetryValue_ProxyUser}" = "" ]; then
               printf "${telemetryData_ProxyUser}"
               read telemetryValue_ProxyUser
               
               while [ 1 ]
               do
                    if [ ${#telemetryValue_ProxyUser} -eq 0 ]; then
                         printf "        Are you sure, you wish to skip proxy credentials[Y/N] :"
                         getAnswerEx 
                         retAns=$?
                         if [ ${retAns} -eq 1 ]; then
                              break;
                         else
                              printf "${telemetryData_ProxyUser}"
                              read telemetryValue_ProxyUser
                         fi
                    elif [ ${#telemetryValue_ProxyUser} -gt 256 ]; then
                         printf "        Proxy username should be less than 257 characters \n"                    
                         printf "${telemetryData_ProxyUser}"                          
                         read telemetryValue_ProxyUser                                         
                    else
                         break
                    fi
               done               
          fi
          
          if [ "${#telemetryValue_ProxyUser}" -ne 0 ]; then 
               if [ "${telemetryValue_ProxyPass}" = "" ]; then
                    printf "${telemetryData_ProxyPass}"
		    stty -echo
                    read telemetryValue_ProxyPass
		    stty echo
               fi

               while [ 1 ]
               do
                    if [ ${#telemetryValue_ProxyPass} -eq 0 ]; then
                         printf "        Continue with blank password[Y/N] :"
                         getAnswerEx 
                         retAns=$?
                         if [ ${retAns} -eq 1 ]; then
                              break;
                         else
                              printf "${telemetryData_ProxyPass}"
		              stty -echo
                              read telemetryValue_ProxyPass
		              stty echo
                         fi
                    else
                         break
                    fi
               done               
          fi
     fi
        #printf "                ${telemetryValue_CompName}
        #        ${telemetryValue_ProxyAddr}
        #        ${telemetryValue_ProxyPort}
        #        ${telemetryValue_ProxyUser}
        #        ${telemetryValue_ProxyPass}\n"
fi

}

isCustomerSubscribed() {
	TMPTelemetryScript="/tmp/tmscript"
	if [ -f $TMPTelemetryScript ]; then
        rm $TMPTelemetryScript
    fi

	echo "CREATE OR REPLACE FUNCTION subscribed() RETURNS text AS \$\$
	DECLARE
    		result text;
	BEGIN
    		select subscribed into result from hpdpidb_app.dp_telemetry_registration;
    	RETURN result;
	END
	\$\$ LANGUAGE plpgsql;

	select subscribed();
	drop function subscribed(); " > $TMPTelemetryScript 

	scriptOutput=`/opt/omni/sbin/omnidbutil -run_script $TMPTelemetryScript -detail`
	dbValue=`echo $scriptOutput | awk -F" " '{ print $5}'`
}

getAnswer() {
while read Answer
          do
          case $Answer in
            Y|y|Yes|yes|YES|"")
                Answer=1
               break
          ;;
            N|n|No|no|NO)
                Answer=0
                break
          ;;
          *)
                Answer=0
               printf "        Please provide a correct option [Y/N]:"
          ;;
          esac
          done
     return $Answer
}

getAnswerEx() {
while read Answer
          do
          case $Answer in
            Y|y|Yes|yes|YES)
                Answer=1
               break
          ;;
            N|n|No|no|NO)
                Answer=0
                break
          ;;
          *)
                Answer=0
               printf "        Please provide a correct option [Y/N]:"
          ;;
          esac
          done
     return $Answer
}

getAnswerForEnable() {
while read Answer
          do
          case $Answer in
            1)
                Answer=1
               break
          ;;
            0)
                Answer=0
                break
          ;;
          *)
               Answer=2
               printf "        Please enter 1 to enable or 0 to disable: "
          ;;
          esac
          done
     return $Answer
}

updateTelemetryDataInDB() {
    if [ "$collectTelemetryData" -ne 0 ]; then
        
        if [ ${#telemetryValue_ProxyPort} -ne 0 ]; then
            if [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 -a ${#telemetryValue_ProxyPort} -gt 0 -a ${#telemetryValue_ProxyUser} -gt 0 -a ${#telemetryValue_ProxyPass} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}" -proxy_port "${telemetryValue_ProxyPort}" -proxy_user "${telemetryValue_ProxyUser}" -proxy_passwd "${telemetryValue_ProxyPass}"
            elif [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 -a ${#telemetryValue_ProxyPort} -gt 0 -a ${#telemetryValue_ProxyUser} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}" -proxy_port "${telemetryValue_ProxyPort}" -proxy_user "${telemetryValue_ProxyUser}"
            elif [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 -a ${#telemetryValue_ProxyPort} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}" -proxy_port "${telemetryValue_ProxyPort}"
            elif [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}"
            elif [ ${#telemetryValue_CompName} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" 
            fi

            # printf is used here as echo command does not interpret \n across different shells in the same way.
            # \n is recognized as tab if -e is passed as an argument linux. But in hp-ux -e option doesn't exist in echo.
            if [ $? -ne 0 ]; then
                printf "Could not update telemetry details. Please run \n"
                printf "                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name <name> -proxy_URL <URL> -proxy_port <port> -proxy_user <user> -proxy_passwd <password> -update_frequency <frequency> \nto update the details.\n"
            else
                echo "Telemetry details updated successfully."
            fi
	else
            if [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 -a ${#telemetryValue_ProxyUser} -gt 0 -a ${#telemetryValue_ProxyPass} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}" -proxy_user "${telemetryValue_ProxyUser}" -proxy_passwd "${telemetryValue_ProxyPass}"
            elif [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 -a ${#telemetryValue_ProxyUser} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}" -proxy_user "${telemetryValue_ProxyUser}"
            elif [ ${#telemetryValue_CompName} -gt 0 -a ${#telemetryValue_ProxyAddr} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" -proxy_URL "${telemetryValue_ProxyAddr}"
            elif [ ${#telemetryValue_CompName} -gt 0 ]; then
                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name "${telemetryValue_CompName}" 
            fi

            if [ $? -ne 0 ]; then
                printf "Check if IDB service is up and running. Could not update telemetry details. Please run \n"
                printf "                /opt/omni/sbin/omnidbutil -set_telemetry_details -customer_name <name> -proxy_URL <URL> -proxy_port <port> -proxy_user <user> -proxy_passwd <password> -update_frequency <frequency> \nto update the details.\n"
            else
                echo "Telemetry details updated successfully."
            fi
	fi

    fi

}

#end telemetry changes
get_rs_param()
{

  RSConf=$1
  if [ x${USERNAME} = x"" ]
  then
    USERNAME=`cat ${RSConf} |grep -w USERNAME | $AWK -F"=" '{ print $2 }'`
  fi

  if [ x${PASSWORD} = x"" ]
  then
    PASSWORD=`cat ${RSConf} |grep -w PASSWORD | $AWK -F"=" '{ print $2 }'`
  fi

  if [ x${PORT} = x"" ]
  then
    PORT=`cat ${RSConf} |grep -w PORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PG_USER} = x"" ]
  then
    PG_USER=`cat ${RSConf} |grep -w PG_USER | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PG_PORT} = x"" ]
  then
    PG_PORT=`cat ${RSConf} |grep -w PG_PORT | $AWK -F"=" '{ print $2 }'`
  fi


}

rs_pre_check()
{

if [ ! -f "/etc/opt/omni/config/db.config" ]
then
	printf "        Please provide us following information:\n"
fi

}

CheckRSPort()
{
	SERVICES=/etc/services
	TMP=/tmp/omni_tmp/inst.tmp
	TMPRSPORT=$1


	L_PORT=`${NETSTAT} -an | grep -w ${TMPRSPORT} | grep LISTEN`
	OC=`cat "${SERVICES}" | sed -e 's/[	]/ /g' | egrep "^[^#]* +${TMPRSPORT}\/" | $AWK '{print $1}' | uniq`
	if [ "${L_PORT}" ]
	then
		if [ "${OC}" ]
		then
			printf "        Error:    The port number \"${TMPRSPORT}\" for the Reporting Server is not free.\n"
			return 1
		fi
	fi
	printf "        Passed:   Port number \"$TMPRSPORT\" will be used for the Reporting Server.\n"
	return 0
}

validateUsername()
{
	TUSER=${1}
	str_len=`echo ${TUSER} | tr -d  "[^a-zA-Z0-9\_]"`
	if [ ${#TUSER} -eq 0 ]
	then
		# No user input provided defaulting to Administrator
		return 2 #go to default value
	elif [ ${#str_len} -ne 0 ]
	then
		printf "        Username should contain only a-zA-Z0-9_ characters \n"
		return 1 #error
	elif [ ${#TUSER} -gt 256 ]
	then
		printf "        Username should be less than 257 characters \n"
		return 1 #error
	else
		return 0
	fi
}

validatePort()
{
	VPORT=${1}
	str_len=`echo ${VPORT} | tr -d  "[^0-9]"`
	if [ ${#VPORT} -eq 0 ]
	then
		# No user input provided defaulting to Administrator
		return 2 # Assign the default value
	elif [ ${#str_len} -ne 0 ]
	then
		printf "        Please enter only numeric characters\n"
		return 1 # error
	elif [ ${#VPORT} -gt 5 ]
	then
		printf "        Reporting Server port should be less than 6 characters \n"
		return 1 # error
	elif [ ${VPORT} -lt 1024 ] || [ ${VPORT} -gt 65535 ]
	then
		printf "        Standard port valid range is [1024 - 65535]\n"
		return 1 # error
	elif [ ${VPORT} -eq 8080 ] || [ ${VPORT} -eq 8081 ]
	then
		printf "        Standard HTTP [8080]  and HTTPS[8081] ports not allowed\n"
		return 1 # error
	else
		CheckRSPort ${VPORT}
		rc=$?
		if [ ${rc} -eq 0 ]
		then
			return 0
		else
			return 1
		fi
	fi
}

get_reporting_db_details()
{

        #get db port
        port_line=`awk 'NR==2' /etc/opt/omni/server/DBconfig/db.properties`
        RSPGPORT=`echo $port_line | sed "s/[^0-9]//g"`

        #get db username
        user_line=`awk 'NR==3' /etc/opt/omni/server/DBconfig/db.properties`
        RSPGUSER=`echo $user_line | awk -F"=" '{print $2;}'`

        #get db password
        pass_line=`awk 'NR==4' /etc/opt/omni/server/DBconfig/db.properties`
        RSPGPASS=`echo $pass_line | awk -F"password=" '{print $2;}'`

        RSPGGROUP=`id -gn ${RSPGUSER}`
        echo "localhost:${RSPGPORT}:*:${RSPGUSER}:${RSPGPASS}" > ${PG_DATA_TMP}/pgpass.conf
        chmod 600 ${PG_DATA_TMP}/pgpass.conf
        chown ${RSPGUSER}:${RSPGGROUP} ${PG_DATA_TMP}/pgpass.conf
}

RS_setup()
{
	CMD_READINPUT_PASSWD="read -s"
	#Installation path
	AS_HOME=/opt/omni/AppServer
	AS_XML=/etc/opt/omni/server/AppServer
        PG_INSTALL=/opt/omni/RS_idb
	HOST_NAME=`hostname -f`
	OPT="Y"
	PSQL=${PG_INSTALL}/bin/psql
	LOGFILE=/var/log/InstallReporting.log
	RSConf=/etc/db.config

    RSOMNI=/tmp/rs_omni_tmp
    mkdir $RSOMNI 2>/dev/null

	reportingHeader="        Reporting Server \n     ---------------------------------------------------------------------------"
	reportingFooter="     ---------------------------------------------------------------------------"
	printf "\t\t\t$reportingHeader\n"
	printf "$reportingFooter\n"

	printf "        Checking if Cell Manager is found on system \n"

	#check if cell Manager is installed
	CS=`rpm -qa | grep OB2-CS`
	RS=`rpm -qa | grep OB2-RS-REST`
	if [ "$CS" != "" ] && [ "$RS" = "" ]
	then
		printf "        Cell Manager is found on system.\n"
		printf "        Reporting Server Installation is not supported along with Cell Manager or Clients, exiting the Installation!!!\n"
		rm -rf ${RSOMNI}
		return 1
	fi


    printf "        Verifying if Reporting Server is already installed...\n"
    if [ "$RS" != "" ]
    then
        FileName=`rpm -q --queryformat %{NAME} ${RS}`
        new_version=`rpm -qp --queryformat %{VERSION} ${SrcDir}/linux_x86_64/DP_DEPOT/${FileName}*.rpm`
        installed_version=`rpm -q --queryformat %{VERSION} ${RS}`
        if [ "${new_version}" \> "${installed_version}" ]
        then
            printf "        Reporting Server ${installed_version} version found. \n"
            printf "        Please confirm to upgrade to ${new_version} [Y/N]:"
            getAnswerEx
            retAns=$?
            if [ ${retAns} -eq 0 ]
            then
                printf "        Installation Terminated!!!\n"
                rm -rf ${RSOMNI}
                exit 2;
            else
                printf "        Proceeding with Reporting Server Upgrade.\n"
                printf "        During upgrade all services will be restarted. \n"
                touch ${RSOMNI}/RS_UPGRADE
                
                #Copy the version to upgrade from
                echo "INSTALLED_VERSION:$installed_version" > ${RSOMNI}/RS_UPGRADE
                echo "NEW_VERSION:${new_version}" >> ${RSOMNI}/RS_UPGRADE

                case ${installed_version} in

                *)
                
                        #create pgpass.conf file with all reporting details
                        get_reporting_db_details

                        #check for client installed
                        GatherInstalledPackets

                        #Uninstall everything
                        UninstallEverything

                        #Upgrade the OB2-CORE RPM
                        printf "        Updating OB2-CORE/OB2-TS-CORE/OB2-TS-JRE/OB2-TS-AS package\n"
                        rpm -U --replacepkgs --replacefiles --nodeps ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-CORE-A*.rpm ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-CORE-A*.rpm ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-JRE*.rpm ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-AS*.rpm >> ${LOGFILE} 2>&1
                        rc=$?
                        if [ ${rc} -ne 0 ]
                        then
                             printf "        ERROR: Failed to Upgrade CORE/TS_CORE/TS_JRE/TS_AS Packages (Return code = ${rc})\n"
                             rm -rf "${RSOMNI}"
                             return 2
                        fi


                        #Upgrade the OB2-RS-IDB RPM
                        printf "        Updating OB2-RS-IDB package\n"
                        rpm -U --replacepkgs --replacefiles --nodeps ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-RS-IDB*.rpm >> ${LOGFILE} 2>&1
                        rc=$?
                        if [ ${rc} -ne 0 ]
                        then
                            printf "        ERROR: Failed to Upgrade OB2-RS-IDB for Reporting Server (Return code = ${rc})\n"
                            rm -rf "${RSOMNI}"
                            return 2
                        fi
                

                
                        #Upgrade the OB2-RS-REST RPM    
                        printf "        Updating OB2-RS-REST package\n"
                        rpm -U --replacepkgs --replacefiles --nodeps ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-RS-REST*.rpm >> ${LOGFILE} 2>&1
                        rc=$?
                        if [ ${rc} -ne 0 ]
                        then
                            printf "        ERROR: Failed to Upgrade OB2-RS-REST for Reporting Server (Return code = ${rc})\n"
                            rm -rf "${RSOMNI}"
                            return 2
                        fi

                        if [ "$InstalledPacketsList" != "" ]; then
                           Packets=$InstalledPacketsList
                           ClientInstall
                        fi

                         #end of version upgrade for A.10.20
                        ;;

                *)
                    #unsupported version
                    printf "ERROR: Unsupported version detected for upgrade"
		    exit 1
                    ;;

                esac
                #end of case for checking upgrades
                
                rm -rf  ${RSOMNI}
                printf "        Reporting Server Upgrade Completed Successfully!!!\n"
                return 0
            fi
        else
            printf "        Reporting Server Version ${installed_version} is already installed.\n"
            printf "        Exiting Installation!!!\n"
            rm -rf  ${RSOMNI}
            return 2
        fi
    fi

	# Pre check for files required during RS REST installation

	printf "\n"
	printf "        Please provide the following information for Reporting Server,\n"
	#GET USERNAME
	while [ 1 ]
	do
		if [ "${RSUSERNAME}" = "" ]
		then	
			printf "        Enter Username[Administrator]:"
			read RSUSERNAME
		fi
		validateUsername ${RSUSERNAME}
		rc=$?
		if [ ${rc} -eq 0 ]
		then
			break
		elif [ ${rc} -eq 1 ]
		then
			RSUSERNAME="" #Validation failed as start again
			continue
		elif [ ${rc} -eq 2 ]
		then
			RSUSERNAME="Administrator"
			break
		fi
	done

	#GET PASSWORD 
	while [ 1 ]
	do
		if [ "${RSPASSWORD}" = "" ]
		then
			printf "        Enter Password:"
			$CMD_READINPUT_PASSWD RSPASSWORD
			printf "\n"
			ret=`echo ${RSPASSWORD} | grep "[A-Z]" | grep "[a-z]" | grep "[0-9]" | grep "[*._-]"`
			rc=$?
			if [ ${#RSPASSWORD} -eq 0 ]
			then
				# Password cannot be blank ask again
				printf "        Password cannot be left blank!!!\n"
			elif [ "${#RSPASSWORD}" -lt "8" ] || [ "${#RSPASSWORD}" -gt "20" ]
			then
				#Password must be between 8 to 20 characters
				printf "        Password must be between 8 to 20 characters.\n"
				RSPASSWORD=""
				continue
			elif [ ${rc} -ne 0 ]
			then
				# Password criteria does not match, criteria is One Upper Case, One digit and special characters as *,.,_,-
				printf "        Password must include at least one upper case letter and one digit\n"
				printf "        Also includes at least one of these special characters: an asterisk ( * ), a dot ( \. ), an hyphen ( - ), or an underscore (_)\n"
				RSPASSWORD=""
				continue
			else
				printf "        Confirm Password:"
				$CMD_READINPUT_PASSWD RSREPASSWD
				printf "\n"
				if [ "${RSPASSWORD}" != "${RSREPASSWD}" ]
				then
					printf "        ERROR!!! Password do not match. Please Reenter"
					printf "\n"
					RSPASSWORD=""
					continue
				else
					break
				fi
			fi
		else
			break
		fi
	done

	#GET PORT
	while [ 1 ]
	do
		if [ "${RSPORT}" = "" ]
		then
			printf "        Enter Port[8443]:"
			read RSPORT
		fi
		validatePort ${RSPORT}
		rc=$?
		if [ ${rc} -eq 0 ]
		then
			break
		elif [ ${rc} -eq 1 ]
		then
			RSPORT="" #Validation failed as start again
			continue
		elif [ ${rc} -eq 2 ]
		then
			RSPORT="8443"
			CheckRSPort ${RSPORT}
			rc=$?
			if [ ${rc} -eq 0 ]
			then
				break
			fi
		fi
  	done
		

	printf "\n"
	printf "        Please provide the following information for Reporting Server Database,\n"
	
	# GET DB Port
	while [ 1 ]
  	do
		if [ "${RSPGPORT}" = "" ]
		then
			printf "        Enter Port[5432]:"
			read RSPGPORT
		fi
		validatePort ${RSPGPORT}
		rc=$?
		if [ ${rc} -eq 0 ]
		then
			if [ ${RSPGPORT} -eq ${RSPORT} ]
			then
				printf "        Please provide different ports for Reporting Server Database Service and Application Service. \n"
				RSPGPORT=""
				continue
			fi
			break
		elif [ ${rc} -eq 1 ]
		then
			RSPGPORT=""
			continue
		elif [ ${rc} -eq 2 ]
		then
			RSPGPORT="5432"
			if [ ${RSPGPORT} -eq ${RSPORT} ]
			then
				printf "        Please provide different ports for Reporting Server Database Service and Application Service. \n"
				RSPGPORT=""
				continue
			fi
			CheckRSPort ${RSPGPORT}
			rc=$?
			if [ ${rc} -eq 0 ]
			then
				break
			else
				RSPGPORT=""
				continue
			fi
		fi
	done

	#End the user input
	touch ${RSOMNI}/Apps_port 
	echo ${RSPORT} > ${RSOMNI}/Apps_port
	touch ${RSOMNI}/pguser
	echo ${RSPGUSER} > ${RSOMNI}/pguser
	touch ${RSOMNI}/pgport
	echo ${RSPGPORT} > ${RSOMNI}/pgport
	RSPGGROUP=`id -gn ${RSPGUSER}`
	ENCPASSWD=`echo ${RSPASSWORD} | base64`

	if [ ! -d /var/opt/omni ]; then
		mkdir -p /var/opt/omni
		chmod 755 /var/opt/omni
		chown -R ${RSPGUSER}:${RSPGGROUP} /var/opt/omni
	fi

	if [ ! -d /etc/opt/omni ]; then
		mkdir -p /etc/opt/omni
		chmod 755 /etc/opt/omni
		chown -R ${RSPGUSER}:${RSPGGROUP} /etc/opt/omni
	fi
	# Ask Confirmation
	printf "\n"
	printf "        Reporting Server Details:\n"
	printf "                Host:${HOST_NAME}\n"
	printf "                Username:${RSUSERNAME}\n"
	printf "                Port:${RSPORT}\n"
	printf "        Reporting Server Database Details:\n"
	printf "                Username:${RSPGUSER}\n"
	printf "                Port:${RSPGPORT}\n"

	if [ ! -f ${RSConf} ]
	then
		touch /etc/update.config
		echo "USERNAME=${RSUSERNAME}" > /etc/update.config
		echo "PASSWORD=${RSPASSWORD}" >> /etc/update.config
		echo "PORT=${RSPORT}" >> /etc/update.config
		echo "PG_USER=${RSPGUSER}" >> /etc/update.config
		echo "PG_Port=${RSPGPORT}" >> /etc/update.config
	fi

	if [ ${SILENTINSTALL} -eq 1 ]
	then
		#Silent Install is et making retAns to TRUE
		retAns=1
	else
		printf "        Do you want to continue with the installation? [Y/N]:"
		getAnswerEx
		retAns=$?
	fi
	if [ ${retAns} -eq 0 ]
	then
		printf "        Exiting the Installation...\n"
		rm -rf "${RSOMNI}"
		exit 1
	else
		# INSTALL RPM
		# Installing CORE
		printf "        Installing OB2-CORE package\n"
		core_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-CORE-A*` 
		rpm -U --replacepkgs --replacefiles --nodeps ${core_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${core_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi
		# Installing TS CORE
		printf "        Installing OB2-TS-CORE package\n"
		ts_core_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-CORE-A*`
		rpm -U --replacepkgs --replacefiles --nodeps ${ts_core_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${ts_core_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi
		# Install the JRE
		printf "        Installing OB2-TS-JRE package\n"
		jre_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-JRE*`
		rpm -U --replacepkgs --replacefiles --nodeps ${jre_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${jre_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi

	        # Install the idb 
		printf "        Installing OB2-RS-IDB package\n"
		rs_idb_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-RS-IDB*` 
		rpm -U --replacepkgs --replacefiles --nodeps ${rs_idb_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${rs_idb_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi

	        # Install the AS 
		printf "        Installing OB2-TS-AS package\n"
		as_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-TS-AS*` 
		rpm -U --replacepkgs --replacefiles --nodeps ${as_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${as_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi

	        # Install the REST 
		printf "        Installing OB2-RS-REST package\n"
		reporting_rpm=`ls  ${SrcDir}/linux_x86_64/DP_DEPOT/OB2-RS-REST*` 
		rpm -U  --replacepkgs --replacefiles --nodeps ${reporting_rpm} >> ${LOGFILE} 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        Error installing ${reporting_rpm} RPM\n"
			rm -rf "${RSOMNI}"
			return 1
		fi
                      
		RSPGPASS=`cat ${PG_INSTALL}/pgpass.tmp`
		echo "localhost:${RSPGPORT}:*:${RSPGUSER}:${RSPGPASS}" > ${PG_INSTALL}/pgpass.conf
		chmod 600 ${PG_INSTALL}/pgpass.conf
		chown ${RSPGUSER}:${RSPGGROUP} ${PG_INSTALL}/pgpass.conf

		# RUN PSQL and update Username and Password
		su - ${RSPGUSER} -c "PGPASSFILE=\"${PG_INSTALL}/pgpass.conf\" ${PG_INSTALL}/bin/psql -U ${RSPGUSER} -d Reporting_DB -w -h localhost -p ${RSPGPORT} -t -c \"INSERT into rs_db.reporting_details (hostname,username,password,port) values ('$HOST_NAME','$RSUSERNAME','$ENCPASSWD',$RSPORT)\" " >> $LOGFILE 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        ERROR: Failed to Upgrade Reporting Server database (Return code = ${rc})\n"
			rm -f "${PG_INSTALL}/pgpass.tmp"
			rm -f "${PG_INSTALL}/pgpass.conf"
			return 1
		fi 

		if [ ${RSPORT} -ne 8443 ]
		then
			# Update the PORT
			sed -e "s/socket-binding name=\"https\" port=.*\"/socket-binding name=\"https\" port=\"${RSPORT}\"/g" ${AS_XML}/standalone.xml > ${AS_XML}/standalone.xml_tmp
			mv ${AS_XML}/standalone.xml_tmp ${AS_XML}/standalone.xml
			sleep 20
		fi

		HOST_NAME=127.0.0.1

		#RESTART the Web Server
		printf "        Restarting the Reporting Server Application Service to update the configuration\n"
		su - ${RSPGUSER} -c "${AS_HOME}/bin/jboss-cli.sh --connect --controller=${HOST_NAME}:14505 command=:shutdown" >> $LOGFILE 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        ERROR: Failed to stop Reporting Server Service (Return code = ${rc})\n"
			rm -f "${PG_INSTALL}/pgpass.tmp"
			rm -f "${PG_INSTALL}/pgpass.conf"
			return 1
		fi

		sleep 20

		nohup su - ${RSPGUSER} -c "${AS_HOME}/bin/standalone.sh -b 0.0.0.0 -bmanagement 127.0.0.1  &" >>$LOGFILE 2>&1
		rc=$?
		if [ ${rc} -ne 0 ]
		then
			printf "        ERROR: Failed to start Reporting Server Service (Return code = ${rc})\n"
			rm -f "${PG_INSTALL}/pgpass.tmp"
			rm -f "${PG_INSTALL}/pgpass.conf"
			return 1
		fi
		sleep 20
		
		printf "        Installation Successful!\n"
		printf "        Reporting Server is ready to Import in Cell Manager\n"
		rm -rf "${RSOMNI}"
		rm -f "${PG_INSTALL}/pgpass.tmp"
		rm -f "${PG_INSTALL}/pgpass.conf"
	fi
	return 0
}

usage()
{
  echo
  echo "Usage synopsis:"
  echo
  echo "omnisetup.sh -version | -help"
  echo
  echo "omnisetup.sh [-source directory] [-server name] [-no_peer_verify] [-install component-list ] [-inetport inetPort]"
  echo "             [-IS] [-CM] [-bundleadd bundlenumber] [-bundlerem bundlenumber] [-installpatch] [-script scriptName]"
  echo "             [-extractpacket] [-os osname] [-platform platformname] [-install component-list] [-targetfolder /directory]"
  echo "             [-accept_obsolescence] [-no_telemetry] [-RS] [-no_idbbackupcheck]"
  echo "             [-compname compName] [-proxyhost ProxyAddress] [-proxyport proxyPort] [-proxyuser proxyUsername] [-proxypasswd proxyPassword]"
  echo "             [-reportingusername reportUserName ] [-reportingpasswd reportPassword] [-reportingport reportPort] [-reportingdbuser reportDBUser] [-reportingdbport reportDBPort]"
  echo "             [-secure_data_comm <0/1>] [-auditlog <0/1> [-retention_months auditLogRetention]]"
  echo
  echo "            component-list:"
  if [ "$SUBPRODUCT" = "AppRM" ]; then #AppRM
  echo "                cc"
  echo "                sap"
  echo "                oracle8"
  echo "                ssea"
  echo "                smisa"
  echo "                docs"
  else #DP
  echo "                cc"
  echo "                da"
  echo "                ndmp"
  echo "                ma"
  echo "                sap"
  echo "                sapdb"
  echo "                saphana"
  echo "                emc"
  echo "                oracle8"
  echo "                sybase"
  echo "                ssea"
  echo "                informix"
  echo "                lotus"
  echo "                db2"
  echo "                mysql"
  echo "                postgresql"
  echo "                smisa"
  echo "                netapp"
  echo "                dellemcunity"
  echo "                vmwaregre_agent"
  echo "                vepa"
  echo "                StoreOnceSoftware"
  echo "                autodr"
  echo "                docs"
  echo "                jpn_ls"
  echo "                fra_ls"
  echo "                chs_ls"
  fi
  echo "                                                 "
  echo "                extractpacket:"
  echo "                osname               platformname"
  echo "                                                 "
  echo "                macos-10.4           i386"
  echo "                linux-oes            i386"
  echo "                linux-x86            i386"
  echo "                linux-ia64           ia64"
  echo "                linux-ppc-64         ppc64"
  echo "                linux-oes-x86-64     x86_64"
  echo "                linux-x86-64         x86_64"
  echo "                hp-ux-11             s800"
  echo "                hp-ux-113x           s800"
  echo "                hp-ux-11             sia64"
  echo "                hp-ux-113x           sia64"
  echo "                aix-51               rs6000"
  echo "                sco_sv_6             i386"
  echo "                solaris-10           sparc"
  echo "                solaris-9            sparc"
  echo "                solaris-8            sparc"
  echo "                solaris-10           x86"
  echo
  echo "Note:       [directory] is the location of $SW_DEPOT directory"
  echo "Note:       [bundlenumber] is the number provided in the bundle installation document."
  echo "Note:       [no_peer_verify] if set it will accept the cell manager host certificate without user verification."
  echo "Note:       [accept_obsolescence] if set it will take obsolescence information as understood and agreed."
  echo "Note:       [-no_idbbackupcheck] if set it will skip the check for IDB backup during upgrade."
  echo
  exit 2
}


# init_var - function copied from .util.sh
init_var()
{ $Debug
  UNAME=`uname -a`
  ARCH=`echo ${UNAME} | $AWK '{print $1}'`
  umask 022
  
  case "${ARCH}" in
    OSF1)
      MACHINE=`echo ${UNAME} | $AWK '{print $5}'`
      OS_REV=`echo  ${UNAME} | $AWK '{print $3}'`
      case "$OS_REV" in
        V5*|P5*)
          SERIES=dec/alpha/osf1-5
          ;;
      esac
      ;;
    HP-UX)
      MACHINE=`echo ${UNAME} | $AWK '{print $5}'`
      OS_REV=`echo  ${UNAME} | $AWK '{print $3}'`
      ;;
    SunOS)
      AWK=nawk
      MACHINE=`echo ${UNAME} | $AWK '{print $5}'`
      OS_REV=`echo  ${UNAME} | $AWK '{print $3}'`
      PATH=$PATH:/usr/ucb:/usr/etc:/usr/sbin
      ;;
    *390*)
      SERIES=ibm/os390/zos-2-1
      MACHINE=zos
      OS_REV  =`echo ${UNAME} | $AWK '{print $3}'`        
      ;;
         
    AIX)
      MACHINE=aix
      OS_REV=`echo ${UNAME} | $AWK '{printf "%s.%s", $4, $3}'`
      case $OS_REV in
        5.3|6*|7*)
          SERIES=ibm/rs6000/aix-51
          ;;
      esac
      ;;
    Linux)
      MACHINE=Linux
      OS_REV=`echo ${UNAME} | $AWK '{print $3}'`
      for word in ${UNAME}; do
        case $word in
          *i[34567]86*)
            if [ -f /etc/novell-release ]; then  #OES 386 
              SERIES=gpl/i386/linux-oes
            else
              SERIES=gpl/i386/linux-x86
            fi
            ;;
          *ia64*)
            SERIES=gpl/ia64/linux-ia64
            ;;
          *ppc64le*)
            SERIES=gpl/ppc64/linux-ppc-64
            ;;	    
          *x86_64*)
            if [ -f /etc/novell-release ]; then  #OES x86-64
              SERIES=gpl/x86_64/linux-oes-x86-64
            else
              SERIES=gpl/x86_64/linux-x86-64
            fi
            ;;
          *s390x*)
             SERIES=ibm/s390x/zlinux-s390x
            ;;
          esac
      done
      ;; 
    SCO_SV)
      MACHINE=`echo ${UNAME} | $AWK '{print $5}'`
      OS_REV=`echo ${UNAME} | $AWK '{print $4}'`
        case $OS_REV in
          6\.0\.*)
            SERIES=sco/i386/sco_sv_6
            ;;
        esac
      ;;
    Darwin)
      MACHINE=`uname -m`
      OS_REV=`echo ${UNAME} | $AWK '{print $3}'`
      ;;
    *)
      ;;
  esac
  
  case "${MACHINE}" in
    *9000/7*)
      ADD=`echo ${OS_REV} | sed 's/^..0*//'`
      case "${OS_REV}" in
        *\.11\.*) SERIES="hp/s800/hp-ux-11"
        ;;
      esac
      ;;
    *9000/8*)
      ADD=`echo ${OS_REV} | sed 's/^..0*//'`
      case "${OS_REV}" in
        *\.11\.[12][0123]) SERIES="hp/s800/hp-ux-11"
            ;;
        *\.11\.*) SERIES="hp/s800/hp-ux-113x"
            ;;
      esac
      ;;
    sun4*)
      case "${OS_REV}" in
        5.10|5.11) SERIES="sun/sparc/solaris-10"
                 ;;
        5.9) SERIES="sun/sparc/solaris-9"
                 ;;
        5.8) SERIES="sun/sparc/solaris-8"
                 ;;
        esac
      ;;
    i86pc*)
      case "${OS_REV}" in
        5.10|5.11) SERIES="sun/x86/solaris-10"
                 ;;
        esac
      ;;
    *ia64*)
      ADD=`echo ${OS_REV} | sed 's/^..0*//'`
      case "${OS_REV}" in
        *\.11\.2[23]) SERIES="hp/sia64/hp-ux-11"
            ;;
        *\.11\.*) SERIES="hp/sia64/hp-ux-113x"
            ;;
      esac
      ;;
    Power*)
       case "${OS_REV}" in
          8.* | 9.*) SERIES="apple/ppc/macos-10.4"
          ;;
       esac
       ;;
    i[3456]86)
       case "${OS_REV}" in
          8.* | 9.* | 10.*) SERIES="apple/i386/macos-10.4"
        ;;
       esac 
      ;;
    *x86_64*)
        case "${OS_REV}" in
          1[0-5].*) SERIES="apple/i386/macos-10.4"
        ;;
       esac
      ;;

  esac

  case "${SERIES}" in
    hp/*/hp-ux*)
      OMNIHOME=/opt/omni
      OMNI_LBIN=${OMNIHOME}/lbin
      OMNICONFIG=/etc${OMNIHOME}
    ;;
    
    sun/*/solaris*)
      OMNIHOME=/opt/omni
      OMNI_LBIN=${OMNIHOME}/lbin
      OMNICONFIG=/etc${OMNIHOME}
      ;;
      
    gpl/*/linux*|*s390x*)
      OMNIHOME=/opt/omni
      OMNI_LBIN=${OMNIHOME}/lbin
      OMNICONFIG=/etc${OMNIHOME}
      OMNIDATA=/var${OMNIHOME}
      ;;
      
    apple/*)
      OMNIHOME=/usr/local/omni
      OMNI_LBIN=${OMNIHOME}/bin
      OMNICONFIG=${OMNIHOME}/config 
      ;;
      
    *)
      OMNIHOME=/usr/omni
      OMNI_LBIN=${OMNIHOME}/bin
      OMNICONFIG=${OMNIHOME}/config 
      ;;
    esac
  
  if [ -f $OMNICONFIG/client/omni_info ]; then  # versions >=5.50
    OMNIINFO=$OMNICONFIG/client/omni_info
  elif [ -f $OMNICONFIG/cell/omni_info ]; then  # versions <5.50
    OMNIINFO=$OMNICONFIG/cell/omni_info
  elif [ -f /usr/omni/config/client/omni_info ]; then  # Linux version = 5.50
    OMNIINFO=/usr/omni/config/client/omni_info
  elif [ -f /usr/omni/config/cell/omni_info ]; then   # solaris low versions
    OMNIINFO=/usr/omni/config/cell/omni_info
  elif [ -f /usr/omni/bin/install/omni_info ]; then   # other known places for omni_info of ancient versions of omniback
    OMNIINFO=/usr/omni/bin/install/omni_info
  fi

  if [ "$OMNIINFO" != "" ]; then
    OLDOMNIINFO=`cat $OMNIINFO`
  fi

  SERVICE=omni
  if [ "$OB2NOEXEC" = 1 ]; then
     OMNITMP=/var/opt/omni/tmp/omni_tmp
  else
     OMNITMP=/tmp/omni_tmp
  fi
  TMP=/tmp
}

init_var_extract()
{ $Debug
  SERIES=""
  INSTALL="extractpacket"
  if [ $platform = "i386" ]; then
    if [ $os = "macos-10.4" ]; then
      SERIES="apple/i386/macos-10.4"
    elif [ $os = "linux-oes" ]; then
      SERIES="gpl/i386/linux-oes"
    elif [ $os = "linux-x86" ]; then
      SERIES="gpl/i386/linux-x86"
	elif [ $os = "sco_sv_6" ]; then
      SERIES="sco/i386/sco_sv_6"
	fi
  fi
  if [ $os = "linux-ia64" -a $platform = "ia64" ]; then
    SERIES="gpl/ia64/linux-ia64"
  fi
  if [ $os = "linux-ppc-64" -a $platform = "ppc64" ]; then
    SERIES="gpl/ppc64/linux-ppc-64"
  fi
  if [ $platform = "x86_64" ]; then
    if [ $os = "linux-oes-x86-64" ]; then
      SERIES="gpl/x86_64/linux-oes-x86-64"	
    elif [ $os = "linux-x86-64" ]; then
      SERIES="gpl/x86_64/linux-x86-64"
	fi
  fi
  if [ $platform = "s800" ]; then
    if [ $os = "hp-ux-11" ]; then
      SERIES="hp/s800/hp-ux-11"
    elif [ $os = "hp-ux-113x" ]; then
      SERIES="hp/s800/hp-ux-113x"
	fi  
  fi
  if [ $platform = "sia64" ]; then
    if [ $os = "hp-ux-11" ]; then
      SERIES="hp/sia64/hp-ux-11"
    elif [ $os = "hp-ux-113x" ]; then
      SERIES="hp/sia64/hp-ux-113x"
	fi  
  fi	  
  if [ $os = "aix-51" -a $platform = "rs6000" ]; then
    SERIES="ibm/rs6000/aix-51"
  fi
  if [ $platform = "sparc" ]; then
    if [ $os = "solaris-10" ]; then
      SERIES="sun/sparc/solaris-10"
    elif [ $os = "solaris-9" ]; then
      SERIES="sun/sparc/solaris-9"
	elif [ $os = "solaris-8" ]; then
      SERIES="sun/sparc/solaris-8"  
	fi  
  fi	  
  if [ $os = "solaris-10" -a $platform = "x86" ]; then
    SERIES="sun/x86/solaris-10"
  fi
  
  cd $MMRDir
  rpmfiles=`ls -l | grep .rpm | wc -l`
  depotfiles=`ls -l | grep .depot | wc -l`
  if [ $rpmfiles -gt 1 -o $depotfiles -eq 1 ]; then
    package=MMR
	SrcDir=$MMRDir
  elif [ $depotfiles -gt 1 ]; then
    package=patchhpux
	SrcDir=$MMRDir
  fi
  
  cd $SrcDir
  if [ "$package" = "" ]; then
    CheckWork
	if [ "$TapeMissing" != "Yes" ]; then
      package=MR
    fi
  fi
  
  if [ "$OB2NOEXEC" = 1 ]; then
     OMNITMP=/var/opt/omni/tmp/omni_tmp
  else
     OMNITMP=/tmp/omni_tmp
  fi
}

CheckCSorIS()
{ $Debug

  case "${SERIES}" in
    hp/*/hp-ux*)
       GetDPOBBundles
       if [ "$Bundles" = "" ]; then
          echo "  ${SHORTPRODUCTNAME} is not installed on the system"
          exit 1
         
       else
          IS=`swlist -l fileset $Bundles | grep OMNI-CORE-IS`
          CS=`swlist -l fileset $Bundles | grep OMNI-CS`
          if [ "$CS" != "" -a "$IS" != "" ]; then
            INSTALL=All
            StopService=1
          elif [ "$CS" = "" -a "$IS" != "" ]; then
            INSTALL=ISonly
            StopService=0
          elif [ "$CS" != "" -a "$IS" = "" ]; then
            INSTALL=CSonly
            StopService=1
          elif [ -f "$OMNIHOME/.patch_core" ]; then
            INSTALL=Clientonly
          else
            echo "No ${SHORTPRODUCTNAME} software detected on the target system."
            exit 1  
          fi
       fi
    ;;
    gpl/*/linux*|*s390x*)
          IS=`rpm -qa --queryformat "%{NAME}\n" | grep OB2-CORE-IS`
          CS=`rpm -qa --queryformat "%{NAME}\n" | grep OB2-CS`
          if [ "$CS" != "" -a "$IS" != "" ]; then
            INSTALL=All
            StopService=1
          elif [ "$CS" = "" -a "$IS" != "" ]; then
            INSTALL=ISonly
            StopService=0
          elif [ "$CS" != "" -a "$IS" = "" ]; then
            INSTALL=CSonly
            StopService=1
	      elif [ -f "$OMNIHOME/.patch_core" ]; then
		    INSTALL=Clientonly
		  else
		    echo "No ${SHORTPRODUCTNAME} software detected on the target system."
			exit 1  
          fi
    ;;
	*)
	  if [ -f "$OMNIHOME/.patch_core" ]; then
	    INSTALL=Clientonly
	  else
        echo "No ${SHORTPRODUCTNAME} software detected on the target system."
		exit 1
	  fi
	;;
  esac
}

CheckBundleExist()
{ $Debug
  BundleExist=0
  case "${SERIES}" in
    hp/*/hp-ux*)
       if [ -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch ]; then
          BundleExist=1
          echo "The patch bundle ${MINOR_RELEASE} is already installed. Installing the bundle"
          echo "will reinstall all the patches that are part of the bundle."
          echo "Do you want to continue with the installation? (Y/N)"
          while read Answer
          do
          case $Answer in
            Y|y|Yes|yes|YES)
               break
          ;;
            N|n|No|no|NO)
               exit 0
          ;;
            *)
               echo "Please provide a correct option (Y/N)"
          ;;
          esac
          done
       fi
  ;;
    gpl/*/linux*|*s390x*)
       if [ -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch ]; then
          BundleExist=1
          echo "The patch bundle ${MINOR_RELEASE} is already installed. Reinstalling the bundle will"
          echo "only install the patches that are part of the bundle but currently not available in"
          echo "the system. Do you want to continue with the installation? (Y/N)"
          while read Answer
          do
          case $Answer in
            Y|y|Yes|yes|YES)
               for X in `cat ${OMNIHOME}/.${MINOR_RELEASE}_Patch`
               do
                  PATCH=`echo $X | awk -F: '{print $2}'`
                  if [ "`rpm -qa --queryformat "%{NAME}-%{VERSION}-%{RELEASE}\n" | grep $PATCH`" = "" ]; then
                     grep -v $X ${OMNIHOME}/.${MINOR_RELEASE}_Patch > ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp
                     mv ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp ${OMNIHOME}/.${MINOR_RELEASE}_Patch
                  fi
               done
               break
          ;;
            N|n|No|no|NO)
               exit 0
          ;;
            *)
               echo "Please provide a correct option (Y/N)"
          ;;
          esac
          done
       fi
  ;;
    *)
	  if [ -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch ]; then
        BundleExist=1
		echo "The patch bundle ${MINOR_RELEASE} is already installed. Installing the bundle"
        echo "will reinstall all the patches that are part of the bundle."
        echo "Do you want to continue with the installation? (Y/N)"
        while read Answer
        do
        case $Answer in
          Y|y|Yes|yes|YES)
            break
          ;;
          N|n|No|no|NO)
            exit 0
          ;;
          *)
            echo "Please provide a correct option (Y/N)"
          ;;
        esac
        done
      fi
  ;;
  esac
}

MakeVersionString()
{
    len=`echo $MINOR_RELEASE | $AWK '{print length}'`
    if [ $len = 4 ]; then
      majorNo=`echo $MINOR_RELEASE | $AWK '{print substr($1,2,1)}'`
      minorNo=`echo $MINOR_RELEASE | $AWK '{print substr($1,3,2)}'`
      BDL_VERSION=`echo "A.0$majorNo.$minorNo"`
    elif [ $len = 5 ]; then
      majorNo=`echo $MINOR_RELEASE | $AWK '{print substr($1,2,2)}'`
      minorNo=`echo $MINOR_RELEASE | $AWK '{print substr($1,4,2)}'`
      BDL_VERSION=`echo "A.$majorNo.$minorNo"`
    fi
}

InstallMinorMinor()
{ $Debug
  
  if [ "${INET_PORT}" != "" ]; then
        echo "  INET port cannot be changed during bundle installation"
        echo "  Continuing installation with existing INET port"
        INET_PORT=""
  fi  
    case "${SERIES}" in
    hp/*/hp-ux*)
       if [ -d "${SrcDir}" ]; then
          cd $SrcDir
          if [ `ls *.depot | grep DP*.depot | wc -l 2>/dev/null` -ne 1 ]; then
             echo " Source directory does not contain a unique patch bundle"
             exit 1;
          fi
          MINORPACKET=`ls *.depot | grep DP*.depot 2>/dev/null`
          if [ "$MINORPACKET" = "" ]; then
             echo "No patch bundle exists in current directory"
             exit 1;
          else
             MakeVersionString
             echo "Installing ${BRIEFPRODUCTNAME} $BDL_VERSION"
             CheckBundleExist
             ServiceToStart=0
             CheckCSorIS
             Check1003Installed
             if [ "${INSTALL}" = "Clientonly" ]; then
                  CreateCompPacketsList
                  return 0
             fi
          fi
       fi
    ;;
    gpl/*/linux*|*s390x*)
       if [ -d "${SrcDir}" ]; then
          cd "$SrcDir"
             MakeVersionString
             echo "Installing ${BRIEFPRODUCTNAME} $BDL_VERSION" 
             CheckBundleExist
             PatchList=`ls DPLNX*.rpm`
             CheckCSorIS
             Check1003Installed
             if [ "${INSTALL}" = "Clientonly" ]; then
               CreateCompPacketsList
               return 0
             fi
             if [ "${INSTALL}" = "All" -o "${INSTALL}" = "CSonly" ]; then
                if [ "$collectTelemetryData" -ne 0 ]; then
                  getTelemetryData
                fi             
             fi
             
             case "${INSTALL}" in
                CSonly)
                   for X in DPLNX*.rpm
                   do
                   if [ "`rpm -qp --queryformat "%{NAME}\n" $X | grep -w CS_Patch`" != "" ]; then
                       PatchToInstall=$X
                       break
                   fi
                   done
                   if [ "${PatchToInstall}" = "" ]; then
                      echo " There is no CS patch to install."
                      exit 1;                            
                   else 
                      PatchList=${PatchToInstall}
                   fi
                ;;
                ISonly)
                   for X in DPLNX*.rpm
                   do
                   if [ "`rpm -qp --queryformat "%{NAME}\n" $X | grep -w CS_Patch`" != "" ]; then
                       PatchList=`ls DPLNX*.rpm | grep -v ${X}`
                       break
                   fi
                   done
                ;;
             esac
             if [ -f "${TMP}/Bundle_Contents" ]; then
                rm -f ${TMP}/Bundle_Contents
             fi
             TelemetryStartNeeded=0             
             ServiceToStart=0
             for X in $PatchList
             do
             PatchName=`echo $X | awk '{print substr($0,1, length($0)-4)}'`
             if [ "$BundleExist" -eq 1 ]; then
                if [ "`grep $PatchName ${OMNIHOME}/.${MINOR_RELEASE}_Patch`" != "" ]; then
                   continue
                fi
             fi
             if [ "`rpm -qp --queryformat "%{NAME}\n" $X | grep -w CS_Patch`" != "" ]; then
                echo ""
                echo "The CS patch is getting installed."
                echo "Cell Server services needs to be stopped"
                echo "Do you want to stop the services or exit the installation? (Y/E)"
                while read Answer
                do
                case $Answer in
                    Y|y|yes|Yes|YES)
                       echo "Stopping the Cell Server services"
                       OUTPUT=`/opt/omni/sbin/omnisv stop $DebugOpts 2>&1`
                       if [ $? -ne 0 ]; then
                          echo ${OUTPUT}
                       else
                          echo "Cell Server services successfully stopped."
                       fi
                       ServiceToStart=1
                       if [ `ps aux | grep 'com.hp.im.dp.telemetryclientservice.App' | grep -v grep | wc -l` -gt 0 ]; then
                            ${OMNIHOME}/bin/telemetry/dataprotector-telemetry-client-service.sh stop
                            TelemetryStartNeeded=1                            
                       fi
                       break
                ;;
                    E|e)
                       echo "Exiting the installation"
                       exit 0
               ;;
                    *)
                       echo "Please provide the correct option (Y/E)"
                ;;
                esac
                done
             fi
             echo ${PatchName} >> ${TMP}/Bundle_Contents
             PATCHREVISION=`rpm -qp --queryformat "%{NAME}-%{VERSION}-%{RELEASE}\n" $X`
             echo ${PatchName}:${PATCHREVISION} >> ${OMNIHOME}/.${MINOR_RELEASE}_Patch
             echo "Installing $X ..."
             rpm -Uvh --replacefiles --replacepkgs $X 
             if [ $? -ne 0 ]; then
                echo ""
                echo ""
                echo "Installation of patch ${X} failed."
                echo "You can continue(C) or rollback(R) or exit(E) the installation."
                echo "Continue - will install the rest of the patches from the bundle."
                echo "Rollback - will rollback the installed patches from the bundle "
                echo "           to the MR level."
                echo "Exit     - Will exit the installation. Installing the bundle "
                echo "           again will install the rest of the patches."
                echo "Please enter the option (C/R/E)"
                while read Answer
                do
                case $Answer in
                   C|c)
                      continue 2
                ;;
                   e|E|Exit|EXIT)
                      echo "Exiting the installation"
                      rm -f ${TMP}/Bundle_Contents
                      if [ "$ServiceToStart" -eq 1 ]; then
                         echo "Starting the Cell Server Services"
                        /opt/omni/sbin/omnisv start $DebugOpts
                      fi
                      exit 1
                ;;
                   R|r)
                      echo "Rolling  back the bundle installation"
                      isInstall=1
                      if [ ! -f "${OMNIHOME}/.${MINOR_RELEASE}_Patch" ]; then
                         echo "There is nothing to roll back."
                         exit 0
                      fi
                      DeInstallMMR_Linux
                      rm -f ${TMP}/Bundle_Contents
                      if [ $SuccessFul -eq 1 ]; then
                         rm -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch
                         rm -f ${TMP}/Bundle_Unistall
                         echo "Roll back successful."
                         exit 0
                      else
                         echo "Roll back of patch bundle failed."
                         exit 1
                      fi
                      if [ "$ServiceToStart" -eq 1 ]; then
                         echo "Starting the Cell Server Services"
                         /opt/omni/sbin/omnisv start $DebugOpts
                      fi
                      exit 1
                ;;
                   *)
                      echo "Please provide the correct option (R/C/E)"
                ;;
                esac
                done
             fi
             if [ "$ServiceToStart" -eq 1 ]; then
                echo "Starting the Cell Server Services"
                /opt/omni/sbin/omnisv start $DebugOpts
                ServiceToStart=0
             fi
             if [ "$TelemetryStartNeeded" -eq 1 ]; then
                ${OMNIHOME}/bin/telemetry/dataprotector-telemetry-client-service.sh start
                TelemetryStartNeeded=0
             fi
             done


          if [ "${INSTALL}" = "All" -o "${INSTALL}" = "CSonly" ]; then
                updateTelemetryDataInDB
          fi

             if [ "${INSTALL}" = "All" -o "${INSTALL}" = "CSonly" ]; then
                 AddJavaUser
             fi

             rm -f ${TMP}/Bundle_Contents
             echo "Installation Successful."
             exit 0;
       else
           echo "${SrcDir} does not exist"
           exit 1;
       fi 
     ;;
	 *)
       if [ -d "${SrcDir}" ]; then
         cd $SrcDir
		 MakeVersionString
         echo "Installing ${BRIEFPRODUCTNAME} $BDL_VERSION"
         CheckBundleExist
         ServiceToStart=0
         CheckCSorIS
	     if [ ${INSTALL} = "Clientonly" ]; then
		   CreateCompPacketsList
		   return 0
	     fi
       fi
     ;;
  esac
}

CheckPatchExist()
{ $Debug

  if [ -f .patch_core ]; then
    patchstring=`cat .patch_core`
    patchexist=`echo "$patchstring" | cut -d "_" -f4`
	patchnumber=`echo "$patchstring" | cut -d "(" -f2`
	
	if [ ! -z $patchexist ]; then
	  echo "Patch ${patchnumber%?} is already installed"
	  exit 1
	fi
  fi
}

InstallPatch()
{ $Debug
  
  if [ -f "$OMNIHOME/.patch_core" ]; then
    bdl=`cat $OMNIHOME/.patch_core`
    STR_BDL="BDL"

    if test "${bdl#*$STR_BDL}" != "$bdl"; then
      INSTALL="ClientPatch"
    else
      echo "  No MMR version of ${SHORTPRODUCTNAME} software detected on the target system."
      exit 1
    fi
  else
    echo "  No ${SHORTPRODUCTNAME} software detected on the target system."
    exit 1
  fi
  if [ -d "${SrcDir}" ]; then
    cd "$SrcDir"
    CheckPatchExist
    CreateCompPacketsList
  fi
}

DeInstallMMR_hpux()
{ $Debug
  MakeVersionString
  echo "Uninstalling ${BRIEFPRODUCTNAME} $BDL_VERSION"
  SuccessFul=1
  ServiceToStart=0
  PatchList=`cat ${OMNIHOME}/.${MINOR_RELEASE}_Patch`
  for X in $PatchList
  do
  if [ "`swlist | grep $X`" = "" ]; then
     if [ "$isInstall" -eq 0 ]; then
        SuccessFul=0
        echo "Unable to find $X. May be this patch has already been uninstalled or upgraded by superseded patch."
     fi
     grep -v $X ${OMNIHOME}/.${MINOR_RELEASE}_Patch > ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp
     mv ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp ${OMNIHOME}/.${MINOR_RELEASE}_Patch
     continue
  fi

  if [ "`swlist | grep $X | grep 'Cell Server'`" != "" ]; then
     echo ""
     echo "The CS patch is getting un-installed."
     echo "Cell Server services needs to be stopped"
     echo "Do you want to stop the services or exit the un-installation? (Y/E)"
     while read Answer
     do
     case $Answer in
         Y|y|yes|Yes|YES)
            echo "Stopping the Cell Server services"
            /opt/omni/sbin/omnisv stop $DebugOpts
            ServiceToStart=1
            break
     ;;
         E|e)
            echo "Exiting the installation"
            exit 0
     ;;
         *)
            echo "Please provide the correct option (Y/E)"
     ;;
     esac
     done
  fi

  /usr/sbin/swremove -x logfile=/tmp/BundleInstall_sd.log -x mount_all_filesystems=false $X
  if [ $? -eq 0 ]; then
     echo "Uninstall of $X successful."
     if [ -f  ${OMNIHOME}/.${MINOR_RELEASE}_Patch ]; then
        grep -v $X ${OMNIHOME}/.${MINOR_RELEASE}_Patch > ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp
        mv ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp ${OMNIHOME}/.${MINOR_RELEASE}_Patch
     fi
  else
     SuccessFul=0
     echo "Unable to uninstall $X. Please check /tmp/BundleInstall_sd.log and uninstall manually."
  fi
  if [ "$ServiceToStart" -eq "1" ]; then
     echo "Starting the Cell Server Services"
     /opt/omni/sbin/omnisv start $DebugOpts
     ServiceToStart=0
  fi
  done
}

DeInstallMMR_Linux()
{ $Debug
  MakeVersionString
  echo "Uninstalling the ${BRIEFPRODUCTNAME} $BDL_VERSION"
  SuccessFul=1
  ServiceToStart=0
  TelemetryStartNeeded=0
  for X in `cat ${OMNIHOME}/.${MINOR_RELEASE}_Patch`
  do
  PATCHTOREMOVE=`echo $X | awk -F: '{print $2}'`
  if [ "`rpm -qa --queryformat "%{NAME}-%{VERSION}-%{RELEASE}\n" | grep $PATCHTOREMOVE`" = "" ]; then
     if [ "$isInstall" -eq 0 ]; then
        SuccessFul=0
        echo "Unable to find $X. May be this patch has already been uninstalled or upgraded by superseded patch."
     fi
     grep -v $X ${OMNIHOME}/.${MINOR_RELEASE}_Patch > ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp
     mv ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp ${OMNIHOME}/.${MINOR_RELEASE}_Patch
     continue
  fi

  if [ "`echo $PATCHTOREMOVE | grep -w CS_Patch`" != "" ]; then
     echo ""
     echo "The CS patch is getting un-installed."
     echo "Cell Server services needs to be stopped"
     echo "Do you want to stop the services or exit the un-installation? (Y/E)"
     while read Answer
     do
     case $Answer in
         Y|y|yes|Yes|YES)
            echo "Stopping the Cell Server services"
            /opt/omni/sbin/omnisv stop $DebugOpts
            ServiceToStart=1
            if [ `ps aux | grep 'com.hp.im.dp.telemetryclientservice.App' | grep -v grep | wc -l` -gt 0 ]; then
                 ${OMNIHOME}/bin/telemetry/dataprotector-telemetry-client-service.sh stop
                 TelemetryStartNeeded=1                            
            fi
            break
     ;;
         E|e)
            echo "Exiting the installation"
            exit 0
     ;;
         *)
            echo "Please provide the correct option (Y/E)"
     ;;
     esac
     done
  fi

  rpm -ev $PATCHTOREMOVE 
  if [ $? -eq 0 ]; then
     echo "Uninstall of $X successful."
     grep -v $X ${OMNIHOME}/.${MINOR_RELEASE}_Patch > ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp
     mv ${OMNIHOME}/.${MINOR_RELEASE}_Patch.tmp ${OMNIHOME}/.${MINOR_RELEASE}_Patch
  else
     SuccessFul=0
     echo "Unable to uninstall $X. Please uninstall manually."
  fi
  if [ "$ServiceToStart" -eq "1" ]; then
     echo "Starting the Cell Server Services"
     /opt/omni/sbin/omnisv start $DebugOpts
     ServiceToStart=0
  fi
  if [ "$TelemetryStartNeeded" -eq 1 ]; then
     ${OMNIHOME}/bin/telemetry/dataprotector-telemetry-client-service.sh start
     TelemetryStartNeeded=0
  fi
  
  done
}

RemoveMinorMinor()
{ $Debug

  case "${SERIES}" in
    hp/*/hp-ux*)
       
       if [ -f "${OMNIHOME}/.${MINOR_RELEASE}_Patch" ]; then
          isInstall=0
          DeInstallMMR_hpux
          if [ $SuccessFul -eq 1 ]; then
             rm -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch
             echo "Un-installation successful."
             exit 0
          else
             echo "Uninstallation of patch bundle failed. Please try to un-install"
             echo "the failed patches manually."
             exit 1
          fi
       else
          echo "There is no ${MINOR_RELEASE} patch bundle installed"
          exit 1
       fi          
     ;;
    gpl/*/linux*|*s390x*)
       if [ -f "${OMNIHOME}/.${MINOR_RELEASE}_Patch" ]; then
          isInstall=0
          DeInstallMMR_Linux
          if [ $SuccessFul -eq 1 ]; then
             rm -f ${OMNIHOME}/.${MINOR_RELEASE}_Patch
             echo "Un-installation successful."
             exit 0
          else
             echo "Uninstallation of patch bundle failed. Please try to un-install"
             echo "the failed patches manually."
             exit 1
          fi
       else
          echo "There is no ${MINOR_RELEASE} patch bundle installed"
          exit 1
       fi
     ;;
  esac
}

InitializeAvailablePacketList()
{ $Debug
  case "${SERIES}" in 
    sun/sparc/solaris-8)
      PegasusDependPackets="smisa"
      IntegrationPackets="informix lotus oracle8 sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    sun/sparc/solaris-9)
      PegasusDependPackets="smisa"
      IntegrationPackets="informix lotus oracle8 sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    sun/sparc/solaris-10)
      PegasusDependPackets="smisa"
      IntegrationPackets="informix lotus oracle8 sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    sun/x86/solaris-10)
      PegasusDependPackets=""
      IntegrationPackets="oracle8"
      NonIntegrationPackets="da ma cc"
      ;;
    hp/s800/hp-ux-11)
      PegasusDependPackets=""
      IntegrationPackets="db2 emc informix oracle8 sapdb sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    hp/s800/hp-ux-113x)
      PegasusDependPackets="smisa"
      IntegrationPackets="db2 emc informix oracle8 sapdb sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    hp/sia64/hp-ux-11)
      PegasusDependPackets="smisa"
      IntegrationPackets="db2 emc informix oracle8 sapdb sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    hp/sia64/hp-ux-113x)
      PegasusDependPackets="smisa"
      IntegrationPackets="db2 emc informix oracle8 sapdb sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    dec/alpha/osf1-4)
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets="da cc"
      ;;
    dec/alpha/osf1-5)
      PegasusDependPackets=""
      IntegrationPackets="oracle8 sap informix"
      NonIntegrationPackets="da ma cc"
      ;;
    ibm/rs6000/aix*)
      PegasusDependPackets=""
      IntegrationPackets="db2 informix lotus oracle8 sapdb sap sybase"
      NonIntegrationPackets="da ma cc"
      ;;
    gpl/i386/linux-x86)
      PegasusDependPackets="smisa"
      IntegrationPackets="db2 informix lotus oracle8 sapdb sap sybase ssea"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls autodr"
      ;;
    gpl/i386/linux-oes)
      PegasusDependPackets=""
      IntegrationPackets="db2 oracle8 sapdb sap"
      NonIntegrationPackets="da ma cc docs jpn_ls fra_ls chs_ls"
      ;;
    gpl/ia64/linux-ia64)
      PegasusDependPackets="smisa"
      IntegrationPackets="oracle8 sap sapdb informix"
      NonIntegrationPackets="da ma cc docs jpn_ls fra_ls chs_ls autodr"
      ;;
    gpl/x86_64/linux-x86-64)
      SmisaDependPackets="netapp_array dellemcunity"
      PegasusDependPackets="smisa netapp_array vmwaregre_agent vepa dellemcunity"
      IntegrationPackets="db2 informix lotus oracle8 sapdb saphana sap sybase ssea postgresql_agent mysql_agent"
      NonIntegrationPackets="da ndmp ma cc docs jpn_ls fra_ls chs_ls autodr StoreOnceSoftware vepa vmwaregre_agent"
      ;;
    gpl/x86_64/linux-oes-x86-64)
      PegasusDependPackets=""
      IntegrationPackets="db2 oracle8 sapdb sap"
      NonIntegrationPackets="da ma cc docs"
      ;;
    gpl/ppc64/linux-ppc-64)
      PegasusDependPackets=""
      IntegrationPackets="saphana"
      NonIntegrationPackets="da ma"
      ;;
    ibm/s390x/zlinux-s390x)
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets="da"
      ;;
    sco/i386/sco_sv_6)
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets="da"
      ;;
    apple/*)
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets="da"
      ;;
    ibm/os390*)
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets="da"
      ;;
    *)
      echo "  There is no information about the packets"
      echo "  available for this system. This platform" 
      echo "  is probably not supported."
      echo 
      PegasusDependPackets=""
      IntegrationPackets=""
      NonIntegrationPackets=""
      ;;
  esac
  PlatformPackets="$NonIntegrationPackets $IntegrationPackets $PegasusDependPackets"
}

FullPacketName()
{ $Debug
  case "$1" in
    sap)
      PushPacketFullName="SAP R/3 Integration"
      ;;
    sapdb)
      PushPacketFullName="SAP DB Integration"
      ;;
    saphana)
      PushPacketFullName="SAP HANA Integration"
      ;;
    oracle8)
      PushPacketFullName="Oracle Integration"
      ;;
    informix)
      PushPacketFullName="Informix Integration"
      ;;
    lotus)
      PushPacketFullName="Lotus Integration"
      ;;
    vmwaregre_agent)
      PushPacketFullName="VMware Granular Recovery Extension Agent Integration"
      ;;
    vepa)
      PushPacketFullName="Virtual Environment Integration"
      ;;
    StoreOnceSoftware)
      PushPacketFullName="StoreOnce Software deduplication"
      ;;
    acs)
      PushPacketFullName="ACS Media Agent"
      ;;
    ndmp)
      PushPacketFullName="NDMP Media Agent"
      ;;
    autodr)
      PushPacketFullName="Automatic Disaster Recovery Module"
      ;;
    cc)
      PushPacketFullName="User Interface"
      ;;
    da)
      PushPacketFullName="Disk Agent"
      ;;
    das)
      PushPacketFullName="DAS Media Agent"
      ;;
    ma)
      PushPacketFullName="Media Agent"
      ;;
    pegasus)
      PushPacketFullName="Pegasus Libraries"
      ;;
    omnicf)
      PushPacketFullName="Core"
      ;;
	ts_core)
      PushPacketFullName="TS_Core"
      ;;  
    integ)
      PushPacketFullName="Core of Integrations"
      ;;
    ssea)
      PushPacketFullName="HPE StorageWorks Disk Array XP Agent"
      ;;
    lotus)
      PushPacketFullName="Lotus Integration"
      ;;
    sybase)
      PushPacketFullName="Sybase Integration"
      ;;
    emc)
      PushPacketFullName="EMC Symmetrix Agent"
      ;;
    docs)
      PushPacketFullName="English Documentation (Guides, Help)"
      ;;
    jpn_ls)
      PushPacketFullName="Japanese Documentation (Guides, Help)"
      ;;
    fra_ls)
      PushPacketFullName="French Documentation (Guides, Help)"
      ;;
    chs_ls)
      PushPacketFullName="Chinese Documentation (Guides, Help)"
      ;;
    db2)
      PushPacketFullName="IBM DB2 Integration"
      ;;
    smisa)
      PushPacketFullName="HPE P6000 SMI-S Agent"
      ;;
    netapp)
      PushPacketFullName="NetApp Storage Provider"
      ;;
    netapp_array)
      PushPacketFullName="NetApp_Array Storage Provider"
      ;;
    mysql)
      PushPacketFullName="MySQL Integration"
      ;;
    postgresql)
      PushPacketFullName="PostgreSQL Integration"
      ;;
    postgresql_agent)
      PushPacketFullName="PostgreSQL_Agent Integration"
      ;;
    mysql_agent)
      PushPacketFullName="MySQL Agent Integration"
      ;;
    dellemcunity)
      PushPacketFullName="Dell EMC Unity Storage Provider"
      ;;
    esac
}

#checks whether tape with the suffix as a parameter, exists (f.e. SUN78_IS.PKG)
#output $?=1, TAPEFULLPATH=tape; $?=0, TAPEFULLPATH=""
CheckTapeExistence()
{ $Debug

  TAPENAME="$1"
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" ]; then
    if [ $SDLabel = "SD4" ]; then
      TAPEFULLPATH="$SrcDir/$hpuxfil"
    elif [ $SDLabel = "SD2" ]; then
      TAPEFULLPATH="$SrcDir/$CorePatch"
    fi
    TAPEPATH="$SrcDir"
  else
  TAPEFULLPATH="$SrcDir/$2/$SW_DEPOT/$TAPENAME"
  TAPEPATH="$SrcDir/$2/$SW_DEPOT"
  fi

  if [ ! -f ${TAPEFULLPATH} ]; then
    TAPEFULLPATH="$SrcDir/"`echo "$2/$SW_DEPOT/$TAPENAME" | tr "[A-Z]" "[a-z]"`
    TAPEPATH="$SrcDir/"`echo "$2/$SW_DEPOT" | tr "[A-Z]" "[a-z]"`
    if [ ! -f ${TAPEFULLPATH} ]; then
      TAPEFULLPATH="$SrcDir/"`echo "$2/$SW_DEPOT/$TAPENAME" | tr "[a-z]" "[A-Z]"`
      TAPEPATH="$SrcDir/"`echo "$2/$SW_DEPOT" | tr "[a-z]" "[A-Z]"`
    fi
  fi

if [ ! -f ${TAPEFULLPATH} ]; then
  TAPENAME="$1"
  TAPEFULLPATH="$SrcDir/$SW_DEPOT/$TAPENAME"
  TAPEPATH="$SrcDir/$SW_DEPOT"

  if [ ! -f ${TAPEFULLPATH} ]; then
    TAPEFULLPATH="$SrcDir/"`echo "$SW_DEPOT/$TAPENAME" | tr "[A-Z]" "[a-z]"`
    TAPEPATH="$SrcDir/dp_depot"
    if [ ! -f ${TAPEFULLPATH} ]; then
      TAPEFULLPATH="$SrcDir/"`echo "$SW_DEPOT/$TAPENAME" | tr "[a-z]" "[A-Z]"`
      TAPEPATH="$SrcDir/$SW_DEPOT"
      if [ ! -f ${TAPEFULLPATH} ]; then
        TAPEFULLPATH="$SrcDir/$TAPENAME"
        TAPEPATH="$SrcDir"
        if [ ! -f ${TAPEFULLPATH} ]; then
          TAPEFULLPATH="$SrcDir/"`echo "$TAPENAME" | tr "[A-Z]" "[a-z]"`
          if [ ! -f ${TAPEFULLPATH} ]; then
            TAPEFULLPATH="$SrcDir/"`echo "$TAPENAME" | tr "[a-z]" "[A-Z]"`
          fi
        fi
      fi
    fi
  fi
fi

  if [ ! -f ${TAPEFULLPATH} ]; then
    TAPEFULLPATH=""
    return 0
  else 
    return 1
  fi
}

CreateAdminFile()
{ $Debug
  mkdir /tmp/omni_tmp 2>/dev/null
  echo "runlevel=nocheck" > /tmp/omni_tmp/admin
  echo "conflict=nocheck" >> /tmp/omni_tmp/admin
  echo "setuid=nocheck" >> /tmp/omni_tmp/admin
  echo "action=nocheck" >> /tmp/omni_tmp/admin
  echo "partial=nocheck" >> /tmp/omni_tmp/admin
  echo "instance=overwrite" >> /tmp/omni_tmp/admin
  echo "idepend=quit" >> /tmp/omni_tmp/admin
  echo "rdepend=nocheck" >> /tmp/omni_tmp/admin
  echo "space=quit" >> /tmp/omni_tmp/admin
}

Solaris_select_packages()
{ $Debug
  to_remove=""

  for pkg in `/usr/bin/pkginfo -c omniback | $AWK '{ print $2 }'` 
  do
    if [ "${pkg}" != "OB2-CORE" ]; then
      if [ "${pkg}" = "OB2-INTG" ]; then
        RemoveInteg=1
      else
        if [ "${pkg}" = "OB2-TS-PEGASUS" ]; then
          RemovePegasus=1
        else
          if [ "${pkg}" = "OB2-PEGASUS" ]; then
            RemovePegasusOld=1
          else
          if [ "${pkg}" = "OB2-CC" ]; then
            RemoveCC=1
          else
            if [ "${pkg}" = "OB2-MA" ]; then
              RemoveMA=1
            else
              if [ "${pkg}" = "OB2-C-IS" ]; then
                RemoveCIS=1
              else
                if [ "${pkg}" = "OB2-INTGP" ]; then
                  RemoveINTEGP=1
                else
                  if [ "${pkg}" = "OB2-PEGP" ]; then
                    RemovePEGP=1
                  else
                    to_remove="${to_remove} ${pkg}"
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
      fi
    else
       RemoveCore=1
    fi
  done
    if [ "${RemovePEGP}" = "1" ]; then
      to_remove="${to_remove} OB2-PEGP"
    fi
    if [ "${RemoveINTEGP}" = "1" ]; then
      to_remove="${to_remove} OB2-INTGP"
    fi
    if [ "${RemoveCIS}" = "1" ]; then
      to_remove="${to_remove} OB2-C-IS"
    fi
    if [ "${RemoveMA}" = "1" ]; then
      to_remove="${to_remove} OB2-MA"
    fi
    if [ "${RemovePegasus}" = "1" ]; then
      to_remove="${to_remove} OB2-TS-PEGASUS"
    fi
    if [ "${RemovePegasusOld}" = "1" ]; then
      to_remove="${to_remove} OB2-PEGASUS"
    fi
    if [ "${RemoveInteg}" = "1" ]; then
      to_remove="${to_remove} OB2-INTG"
    fi
    if [ "${RemoveCC}" = "1" ]; then
      to_remove="${to_remove} OB2-CC"
    fi
    if [ "${RemoveCore}" = "1" ]; then
      to_remove="${to_remove} OB2-CORE"
    fi
  if [ "$to_remove" != "" ]; then
    echo ${to_remove}
  fi
}

Deinstall_Solaris()
{ $Debug
  CreateAdminFile
 
  DEBUG_FILE=/var/tmp/omni.debug
  
  if [ -f ${DEBUG_FILE} ]
  then
    OPTIONS="-nv"
  else
    OPTIONS="-n"
  fi

  PKGS=`Solaris_select_packages`
  retCode=0
  if [ "${PKGS}" != "" ]; then
   echo
   echo  "  Removing ${PKGS}"
   rm -f /var/tmp/OmniBack_pkgrm.log
   for i in ${PKGS}; do
    echo
    echo  "  Removing ${i}"
    case $1 in
     clean) 
      /usr/sbin/pkgrm -n -a /tmp/omni_tmp/admin ${i} >>/var/tmp/OmniBack_pkgrm.log 2>&1
        retCode=$?
        if [ ${retCode} -ne 0 ]; then
          echo "  ${InstalledProductName} software uninstallation failed" 
          echo "  For details check file /var/tmp/OmniBack_pkgrm.log" 
          exit 3
        fi
      ;;
     *)
      /usr/sbin/pkgrm -n -a /tmp/omni_tmp/admin ${i}
        retCode=$?
        if [ ${retCode} -ne 0 ]; then
          echo "  ${InstalledProductName} software uninstallation failed" 
          echo  
          exit 3
        fi
      ;;
    esac
   done
        if [ ${retCode} -eq 0 ]; then
          echo "  ${InstalledProductName} software successfully uninstalled"
          echo
        fi 
  else
    rm -rf /usr/omni
    echo "  ${InstalledProductName} software successfully uninstalled"
    echo
  fi
}

Linux_select_packages()
{ $Debug
  to_remove=""
  for pkg in `rpm -qg --queryformat "%{NAME}\n" Data-Protector |grep OB2`
  do
    if [ "${pkg}" != "OB2-CORE" ]; then
        if [ "${pkg}" = "OB2-RS-REST" ];then
            RemoveRS_REST=1
        else
            if [ "${pkg}" = "OB2-RS-IDB" ];then
               RemoveRS_IDB=1
            else
                if [ "${pkg}" = "OB2-INTEG" ]; then
              RemoveInteg=1
                else
                    if [ "${pkg}" = "OB2-TS-PEGASUS" ]; then
                        RemovePegasus=1
                    else
                        if [ "${pkg}" = "OB2-PEGASUS" ]; then
                           RemovePegasusOld=1
                        else
                            if [ "${pkg}" = "OB2-CC" ]; then
                               RemoveCC=1
                            else
                                if [ "${pkg}" = "OB2-MA" ]; then
                                    RemoveMA=1
                                else
                                    if [ "${pkg}" = "OB2-CORE-IS" ]; then
                                        RemoveCIS=1
                                     else
                                        if [ "${pkg}" = "OB2-INTEGP" ]; then
                                            RemoveINTEGP=1
                                        else
                                            if [ "${pkg}" = "OB2-TS-PEGP" ]; then
                                                RemovePEGP=1
                                            else
                                                if [ "${pkg}" = "OB2-PEGP" ]; then
                                                    RemovePEGPOld=1
                                                else
                                                    if [ "${pkg}" = "OB2-TS-CS" ]; then
                                                        RemoveTS=1
                                                    else
                                                        if [ "${pkg}" = "OB2-TS-CORE" ]; then
                                                            RemoveTSC=1
                                                        else
                                                            if [ "${pkg}" = "OB2-TS-AS" ]; then
                                                                RemoveTSAS=1
                                                            else
                                                                if [ "${pkg}" = "OB2-WS" ]; then
                                                                    RemoveWS=1
                                                                else
                                                                    if [ "${pkg}" = "OB2-JCE-DISPATCHER" ]; then
                                                                        RemoveJCEDISPATCHER=1
                                                                    else
                                                                        to_remove="${to_remove} ${pkg}"
                                                                    fi
                                                                fi
                                                            fi
                                                        fi
                                                    fi
                                                fi
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
       fi
    else
       RemoveCore=1
    fi
  done

    if [ "${RemoveRS_REST}" = "1" ]; then
      to_remove="${to_remove} OB2-RS-REST"
    fi
    if [ "${RemoveRS_IDB}" = "1" ]; then
      to_remove="${to_remove} OB2-RS-IDB"
    fi
    if [ "${RemovePEGP}" = "1" ]; then
      to_remove="${to_remove} OB2-TS-PEGP"
    fi
    if [ "${RemovePEGPOld}" = "1" ]; then
      to_remove="${to_remove} OB2-PEGP"
    fi
    if [ "${RemoveINTEGP}" = "1" ]; then
      to_remove="${to_remove} OB2-INTEGP"
    fi
    if [ "${RemoveCIS}" = "1" ]; then
      to_remove="${to_remove} OB2-CORE-IS"
    fi
    if [ "${RemovePegasus}" = "1" ]; then
      to_remove="${to_remove} OB2-TS-PEGASUS"
    fi
    if [ "${RemovePegasusOld}" = "1" ]; then
      to_remove="${to_remove} OB2-PEGASUS"
    fi
    if [ "${RemoveMA}" = "1" ]; then
      to_remove="${to_remove} OB2-MA"
    fi
    if [ "${RemoveInteg}" = "1" ]; then
      to_remove="${to_remove} OB2-INTEG"
    fi
    if [ "${RemoveWS}" = "1" ]; then
      to_remove="${to_remove} OB2-WS"
    fi
    if [ "${RemoveJCEDISPATCHER}" = "1" ]; then
      to_remove="${to_remove} OB2-JCE-DISPATCHER"
    fi
    if [ "${RemoveCC}" = "1" ]; then
      to_remove="${to_remove} OB2-CC"
    fi
    if [ "${RemoveTSAS}" = "1" ]; then
      to_remove="${to_remove} OB2-TS-AS"
    fi
    if [ "${RemoveTS}" = "1" ]; then
      to_remove="${to_remove} OB2-TS-CS"
    fi
    if [ "${RemoveTSC}" = "1" ]; then
     to_remove="${to_remove} OB2-TS-CORE"
    fi
    if [ "${RemoveCore}" = "1" ]; then
      to_remove="${to_remove} OB2-CORE"
    fi

   for pkg in `rpm -qg --queryformat "%{NAME}\n" Data-Protector |grep Patch`
   do
     to_remove="${pkg} ${to_remove}"
   done
        echo ${to_remove}
}

Linux_Is_SODA_Patch_DP620()
{
  SODA_PATCH=SODA_Patch-A.06.20

  if [ "$1" = "SODA_Patch" ]; then
    SODA_PATCH_INSTALLED=`rpm -qa | grep $SODA_PATCH`
    if [ x${SODA_PATCH_INSTALLED} != "x" ]; then
      return 1
    fi
  fi
  return 0
}

Linux_SODA_Patch_DP620_Uninstall()
{
  SODA_BACKUP_DIR=/var/opt/omni/repackage/SODA_Patch
  SODA_PATCH_S=SODA_Patch
  RETVAL_ERR=1
  RETVAL_OK=0

  rm -f /var/tmp/OmniBack_rpmrm_SODA.log
  rpm -e ${SODA_PATCH_S} >>/var/tmp/OmniBack_rpmrm_SODA.log 2>&1
  if [ $? -ne 0 ]; then
    ErrCount=`cat /var/tmp/OmniBack_rpmrm_SODA.log | grep "Please make sure the ${BRIEFPRODUCTNAME} processes are running" | wc -l`
    if [ $ErrCount = "0" ]; then
      # Some other error than expected happend...
      cat /var/tmp/OmniBack_rpmrm_SODA.log >>/var/tmp/OmniBack_rpmrm.log
      rm -f /var/tmp/OmniBack_rpmrm_SODA.log
      return ${RETVAL_ERR}
    fi  
  else
    cat /var/tmp/OmniBack_rpmrm_SODA.log >>/var/tmp/OmniBack_rpmrm.log
    rm -f /var/tmp/OmniBack_rpmrm_SODA.log
    return ${RETVAL_OK}  
  fi
  rm -f /var/tmp/OmniBack_rpmrm_SODA.log

  # Re-run unistall without uninstall scripts
  echo "  Rerunning ${SODA_PATCH_S} removal (skip uninstall scripts)..." >>/var/tmp/OmniBack_rpmrm.log 2>&1
  rpm -e --noscripts ${SODA_PATCH_S} >>/var/tmp/OmniBack_rpmrm.log 2>&1
  if [ $? -ne 0 ]; then
    return ${RETVAL_ERR}
  fi

  # Do Rollback to MR here, since unistall scripts were skipped
  if [ -d $SODA_BACKUP_DIR ]; then
    cd "$SODA_BACKUP_DIR"
    find . -type f | sed 's/^\.\///' > $SODA_BACKUP_DIR/mr_bak_$$
    cat $SODA_BACKUP_DIR/mr_bak_$$ | cpio -paduVL --no-preserve-owner / > /dev/null 2>&1
    echo "  Rollback Complete ..." >> /var/tmp/OmniBack_rpmrm.log
  fi

  return ${RETVAL_OK}
}

Deinstall_Linux()
{ $Debug

  PKGS=`Linux_select_packages`
  retCode=0
  if [ "${PKGS}" != "" ]; then
    if [ -f /opt/omni/sbin/omnisv ]; then
      /opt/omni/sbin/omnisv stop $DebugOpts
    fi
    if [ -f /opt/omni/lbin/StoreOnceSoftwared ]; then
      /opt/omni/lbin/StoreOnceSoftwared stop
    fi
    if [ `ps aux | grep 'com.hp.im.dp.telemetryclientservice.App' | grep -v grep | wc -l` -gt 0 ]; then
         ${OMNIHOME}/bin/telemetry/dataprotector-telemetry-client-service.sh stop
    fi
   
   if [ $CMUpgrade = "Yes" ]; then
      if [ -f /var/opt/omni/server/db80/pg/PG_VERSION ]; then
          PGVersionOld=`cat /var/opt/omni/server/db80/pg/PG_VERSION`
          PGVersionOldNumber=${PGVersionOld%.*}
          PGVersionNew=11
          if [ $PGVersionOldNumber -lt $PGVersionNew ]; then
              ##############################################################################################################
              # For postgres version upgrade, need to take backup of IDB binaries present in /opt/omni/idb. This path is 
              # cleaned up during upgrade. Ideally the backup should be taken in PREREMOVE_CS but that is executed during
              # both uograde and uninstallation and its not possible to figure out which process is calling it. Hence we have
              # to make these changes here
              ##############################################################################################################
              BackupDBFiles $PGVersionOld
	  fi
      else
          echo "PG_Version file not found, aborting upgrade..."
	  exit 0
      fi
   fi
   echo
   echo  "  Removing ${PKGS}"
   rm -f /var/tmp/OmniBack_rpmrm.log

    #stopping REST services
    RS=`rpm -qa | grep OB2-RS-REST`   
    if [ "$RS" != "" ]; then
    
     /etc/init.d/rs_rest-db stop > /dev/null 2>&1
     rc=`echo $?`
     if [ "$rc" != "0" ]; then
     	echo "        ERROR: Stopping Reporting Server Database Service, please try manually"
     else
        rm -f /etc/init.d/rs_rest-db > /dev/null 2>&1
     fi

      /etc/init.d/rs_rest-as stop > /dev/null 2>&1
     rc=`echo $?`
     if [ "$rc" != "0" ]; then
     	echo "        ERROR: Stopping Reporting Server Application Service, please try manually"
     else
        rm -f /etc/init.d/rs_rest-as > /dev/null 2>&1
     fi
   fi

   for i in ${PKGS}; do
    echo
    echo  "  Removing ${i}"
    case $1 in
     clean)
      Linux_Is_SODA_Patch_DP620 ${i}
      if [ $? = 1 ]; then
        Linux_SODA_Patch_DP620_Uninstall ${i}
        retCode=$?
      else
        rpm -e ${i} >>/var/tmp/OmniBack_rpmrm.log 2>&1
        retCode=$?
      fi
      
      if [ ${retCode} -ne 0 ]; then
        echo "  ${InstalledProductName} software uninstallation failed"
        echo "  For details check file /var/tmp/OmniBack_rpmrm.log"
        exit 3
      fi
      ;;
     *)
      Linux_Is_SODA_Patch_DP620 ${i}
      if [ $? = 1 ]; then
        Linux_SODA_Patch_DP620_Uninstall ${i}
        retCode=$?
      else
        rpm -e ${i} >>/var/tmp/OmniBack_rpmrm.log 2>&1
        retCode=$?
      fi

      if [ ${retCode} -ne 0 ]; then
        echo "  ${InstalledProductName} software uninstallation failed"
        echo "  For details check file /var/tmp/OmniBack_rpmrm.log"
        echo
        exit 3
      fi
      ;;
    esac
    done
      if [ ${retCode} -eq 0 ]; then
        echo "  ${InstalledProductName} software successfully uninstalled"
        echo
      fi
  else
    rm -rf /usr/omni
    echo "  ${InstalledProductName} software successfully uninstalled"
    echo
  fi

}

GetDPOBBundles()
{ $Debug
  Bundles=""
  swlist | $AWK '{ if ($1 != "#" && $1 != "" ) {print $1} }' >$ComponentTempFile
  for Bundle in $DPOBBundles; do
    BundleX=`cat $ComponentTempFile | grep $Bundle`
    if [ "$BundleX" != "" ]; then
      Bundles="$Bundles $BundleX"
    fi
  done

  if [ "$Bundles" != "" ]; then
    if [ "$Minor" != "Add" -a "$Minor" != "Remove" ]; then
    echo "  Bundle names going to be removed: $Bundles"
    fi
    echo
  fi
}

Deinstall_HPUX()
{ $Debug

  GetDPOBBundles

  if [ "$Bundles" = "" ]; then
    echo "  ${SHORTPRODUCTNAME} is not installed on the system"
    echo
  else
    /usr/sbin/swremove -x logfile=/tmp/OmniBack_sd.log -x mount_all_filesystems=false $Bundles
    if [ $? -eq 0 ]; then
      echo "  ${InstalledProductName} software successfully deinstalled"
      echo
    else
      echo "  ${InstalledProductName} software deinstallation failed" 
      echo "  For details check file /tmp/OmniBack_sd.log"
      exit 3
    fi
  fi
}

Deinstall_Other()
{ $Debug
  HOST_NAME=`hostname | tr "[A-Z]" "[a-z]"`
  ${OMNIHOME}/bin/omnicc -export_host ${HOST_NAME} -remove_only 2>/dev/null

  ${OMNIHOME}/bin/dpsvcsetup.sh -uninstall 2>/dev/null
 
  LISTFILES=`ls ${OMNIHOME}/*.fileset 2>/dev/null`
  if [ "$LISTFILES" != "" ]; then
    LISTFILESCAT=`cat ${LISTFILES}`
  fi
  
  if [ -d ${OMNIHOME} -a "$LISTFILESCAT" != "" ]
  then
    cat ${LISTFILES} | xargs rm -rf
  fi
 
  if [ x${OMNIHOME} != "x" -a x${OMNIHOME} != "x/" -a x${OMNIHOME} != "x." -a x${OMNIHOME} != "x.." ]; then
    rm -rf ${OMNIHOME}/*
    rm -rf ${OMNIHOME}/.[A-Z]*
    rm -rf ${OMNIHOME}/.[a-z]*
  fi 
}

UninstallAll()
{ $Debug

  BrandingInit

  BrandingInitVariables

  if [ -f /opt/omni/.omnirc ]; then
    cp /opt/omni/.omnirc /tmp/omni_tmp
  elif [ -f /usr/omni/.omnirc ]; then
    cp /usr/omni/.omnirc /tmp/omni_tmp
  fi
  if [ "$Delete" != "Yes" ]; then
    checkSymLinks
  fi

  echo "  Removing product ${InstalledProductName} from the system..."
  case "$SERIES" in
    hp*)
      Deinstall_HPUX
      ;;
    sun*)
      Deinstall_Solaris $1
      ;;
    gpl*|*s390x*)
      Deinstall_Linux $1
      ;;    
      *)
      Deinstall_Other
      ;;
  esac
  if [ "$link" = "true" ]; then
    reSymLink
  fi
}

DeleteEverything()
{ $Debug

  UninstallAll clean

  echo "  Removing all ${InstalledProductName} directories, including configuration data and IDB files."
  echo
  rm -rf /opt/omni/.[A-Z]* /opt/omni/.[a-z]* /opt/omni/* /usr/omni/* /var/opt/omni/* /etc/opt/omni/* 2>/dev/null
  rm /tmp/omnisetup* 2>/dev/null
}

UninstallEverything()
{ $Debug

  UninstallAll
}

Version()
{ $Debug
  echo "${FULLPRODUCTNAME} $VERSION"
  exit 0
}

LoggingInit()
{
  $Debug
  if [ "${Debug}" != "" ]; then
     return
  fi

  MY_DPDAT=/tmp/dp.dat
  if [ -f ${MY_DPDAT} ]; then
    DEBUG=`cat ${MY_DPDAT} | grep DEBUG`
    if [ x${DEBUG} = x"" ]; then
      return;
    fi
    
    LOG_FILE=/tmp/omnisetup_$$.log
    exec 2>${LOG_FILE}
    set -x
    Debug="set -x"
  fi
}

ProcessInput()
{ $Debug

NOENCRYPTION=1

while [ "$1" != "" ]
do
  case "$1" in
    "-source")
        shift
        if [ "$1" != "" ]
        then
          SrcDir=$1
        else
          echo
          echo "A value for the \"-source\" option is missing!"
          usage
        fi
      ;;
    "-install")
        shift
        if [ "$1" != "" ]
        then
          PacketsList=`echo $1 | $AWK -F, '{for (i=1; (i<=NF); i+=1) {print $i " "}}'`
         for i in $PacketsList
         do
             if [ "$i" = "netapp" ]; then
                Packetnetapp_array="netapp_array"
                PacketsList=$PacketsList" "$Packetnetapp_array
             fi
            	if [ "$i" = "postgresql" ]; then
         		Packetpostgresql_agent="postgresql_agent"
         		PacketsList=$PacketsList" "$Packetpostgresql_agent
    		fi
             if [ "$i" = "mysql" ]; then
                Packetmysql_agent="mysql_agent"
                PacketsList=$PacketsList" "$Packetmysql_agent
             fi
             if [ "$i" = "netapp_array" ]; then
                echo "Currently Not supported!!!!!"
                exit 1
             fi
             
	     if [ "$i" = "postgresql_agent" ]; then
    	        echo "Currently Not supported!!!!!"
                exit 1	
	     fi
             if [ "$i" = "mysql_agent" ]; then
                echo "Currently Not supported!!!!!"
                exit 1
             fi

         done
          Option="Yes"
        else
          echo
          echo "A value for the \"-install\" option is missing!"
          usage
        fi
      ;;
    "-server")
        shift
        if [ "$1" != "" ]
        then
          CellServer=$1
        else
          echo
          echo "A value for the\"-server\" option is missing!"
          usage
        fi
      ;;
    "-debug")
        Debug="set -x"
        LOG_FILE=/tmp/omnisetup_$$.log
        exec 2>${LOG_FILE}
        set -x
        DebugOpts="-debug 1-200 installation.txt"
      ;;
    "-help")
        usage
      ;;
      "-RS")
       AddOptRS="Yes"
      ;;
    "-version")
        Version
      ;;
    "-IS")
        AddOptIS="Yes"
        Option="Yes"
      ;;
    "-CM")
        AddOptCM="Yes"
        Option="Yes"
      ;;
    "-no_peer_verify")
        NoVerifyPeer="Yes"
      ;;
    "-no_checkPrereqScript")
        NoPrereqScript="Yes"
      ;;
    "-no_checkAppServerCert")
        NoVerifyAppServerCert="Yes"
      ;;
    "-no_checkSymLinks")
        NoCheckSymLinks="Yes"
      ;;
    "-no_preReqCheck")
        NoPreReqCheck="Yes"
      ;;
    "-reinstall")
        Reinstall="Yes"
      ;;
    "-Uninstall")                        # Undocumented option. For internal use only!
        Uninstall="Yes"
      ;;
    "-Delete")                           # Undocumented option. For internal use only!
        Delete="Yes"
      ;;
    "")
        return 0
      ;;
    "-bundleadd")
        shift
        obsolescenceInfo=0
        Minor="Add"
        if [ "$1" != "" ]
        then
          MINOR_RELEASE=$1
        else
          echo
          echo "A value for the \"-bundleadd\" option is missing!"
          usage
        fi
        if [ "$SrcDir" = "" ]; then
           SrcDir="`pwd`"
        fi
      ;;
    "-bundlerem")
        shift
        obsolescenceInfo=0
        Minor="Remove"
        if [ "$1" != "" ]
        then
          MINOR_RELEASE=$1
        else
          echo
          echo "A value for the \"-bundlerem\" option is missing!"
          usage
        fi 
      ;; 
	  "-installpatch")
        shift
        obsolescenceInfo=0
        PatchAdd="Add"
        if [ "$SrcDir" = "" ]; then
           SrcDir="`pwd`"
        fi
        break
      ;;
      "-script")
        shift
        if [ "$1" != "" ]
        then
          ScriptName=$1
        else
          echo
          echo "A value for the \"-script\" option is missing!"
          usage
        fi
      ;; 
	"-accept_obsolescence")
       #accept the obsolescence as it is
	   obsolescenceInfo=0
         ;;  
    "-no_telemetry")
         collectTelemetryData=0
         ;;      
    "-no_idbbackupcheck")
	  idbBackupCheck=0
	  ;;
    "-telemetry")
            collectTelemetryData=2
            ;;
    "-compname")
            shift
            if [ "$1" != "" ]
            then
                telemetryValue_CompName=$1
            else
                echo
                echo "A value for the \"-compname\" option is missing!"
                usage
            fi
            ;;
    "-proxyhost")
            shift
            if [ "$1" != "" ]
            then
                telemetryValue_ProxyAddr=$1
            else
                echo
                echo "A value for the \"-proxyhost\" option is missing!"
                usage
            fi
            ;;
    "-proxyport")
            shift
            if [ "$1" != "" ]
            then
                telemetryValue_ProxyPort=$1
            else
                echo
                echo "A value for the \"-proxyport\" option is missing!"
                usage
            fi
            ;;
    "-proxyuser")
            shift
            if [ "$1" != "" ]
            then
                telemetryValue_ProxyUser=$1
            else
                echo
                echo "A value for the \"-proxyuser\" option is missing!"
                usage
            fi
            ;;
    "-proxypasswd")
            shift
            if [ "$1" != "" ]
            then
                telemetryValue_ProxyPass=$1
            else
                echo
                echo "A value for the \"-proxypasswd\" option is missing!"
                usage
            fi
            ;;
    "-inetport")
            shift
            if [ "$1" != "" ]
            then
                INET_PORT=$1
            else
                echo
                echo "A value for the \"-inetport\" option is missing!"
                usage
            fi
            ;;	
	"-extractpacket")
	  obsolescenceInfo=0
      Extract="Yes"
	  ;;
	"-OS"|"-os")
	  if [ "$Extract" = "Yes" ]; then
	    shift
	    if [ "$1" != "" ]
        then
          os=$1
        else
          echo
          echo "A value for the \"-OS\" option is missing!"
          usage
      fi
	  else
	    echo
        echo "Invalid option \"-extractpacket\" specified!"
        usage
      fi
      	;;
	"-platform")
	  if [ "$Extract" = "Yes" ]; then
	    shift
	    if [ "$1" != "" ]
          then
          platform=$1
        else
          echo
          echo "A value for the \"-platform\" option is missing!"
          usage
        fi
	  else
        echo
        echo "Invalid option \"-extractpacket\" specified!"
        usage
      fi	  
      	;;		
    "-targetfolder")
	  if [ "$Extract" = "Yes" ]; then
	    shift
	    if [ "$1" != "" ]
          then
          targetfolder=$1
        else
          echo
          echo "A value for the \"-targetfolder\" option is missing!"
          usage
        fi
	  else
        echo
        echo "Invalid option \"-extractpacket\" specified!"
        usage
      fi	  
      	;;		
    "-reportingusername")
            shift
            if [ "$1" != "" ]
            then
                RSUSERNAME=$1
		SILENTINSTALL=1
            else
                echo
                echo "A value for the \"-reportingusername\" option is missing!"
                usage
            fi
            ;;
    "-reportingpasswd")
            shift
            if [ "$1" != "" ]
            then
                RSPASSWORD=$1
            else
                echo
                echo "A value for the \"-reportingusername\" option is missing!"
                usage
            fi
            ;;
    "-reportingport")
            shift
            if [ "$1" != "" ]
            then
                RSPORT=$1
            else
                echo
                echo "A value for the \"-reportingusername\" option is missing!"
                usage
            fi
            ;;
    "-reportingdbuser")
            shift
            if [ "$1" != "" ]
            then
                RSPGUSER=$1
            else
                echo
                echo "A value for the \"-reportingusername\" option is missing!"
                usage
            fi
            ;;
    "-reportingdbport")
            shift
            if [ "$1" != "" ]
            then
                RSPGPORT=$1
            else
                echo
                echo "A value for the \"-reportingusername\" option is missing!"
                usage
            fi
            ;;
    "-secure_data_comm")
            shift
            if [ "$1" != "" ]
            then
                SEC_DATA_COMM=$1
            else
                echo
                echo "A value for the \"-secure_data_comm\" option is missing!"
                usage
            fi
            ;;
    "-auditlog")
            shift
            if [ "$1" != "" ]
            then
                AUDITLOG=$1
            else
                echo
                echo "A value for the \"-auditlog\" option is missing!"
                usage
            fi
            ;;
    "-retention_months")
          if [ "$AUDITLOG" = "1" ]; then
            shift
            if [ "$1" != "" ]
            then
                AUDITLOG_RETENTION=$1
            else
                echo
                echo "A value for the \"-retention_months\" option is missing!"
                usage
            fi
          else
            echo
            echo "Invalid option \"-auditlog\" not specified but \"-retention_months\" is specified !"
            usage
          fi
          ;;
    *)
      echo "$1": wrong option!
      usage
      ;;
  esac
  shift

done

  if [ "$SrcDir" = "" ]; then
    cd $sh_path
	MMRDir="`pwd`"
    cd ..
    SrcDir="`pwd`"
  else
    if [ -d $SrcDir ]; then
      cd $SrcDir
    fi
  fi

  # Uninstall instructions can be found in chapter 3
  # "Uninstalling Data Protector software" in the "Installation and Licensing Guide"
  if [ "$Uninstall" = "Yes" ]; then
     if [ "$OB2NOEXEC" = 1 ]; then
        mkdir /var/opt/omni/tmp/omni_tmp 2>/dev/null
     else
        mkdir /tmp/omni_tmp 2>/dev/null
     fi
    UninstallEverything  # Uninstall product without removing configuration data and database files.
     if [ "$OB2NOEXEC" = 1 ]; then
        rm -rf /var/opt/omni/tmp/omni_tmp
     else
        rm -rf /tmp/omni_tmp
     fi
    exit 0
  else
    if [ "$Delete" = "Yes" ]; then
     if [ "$OB2NOEXEC" = 1 ]; then
        mkdir /var/opt/omni/tmp/omni_tmp 2>/dev/null
     else
        mkdir /tmp/omni_tmp 2>/dev/null
     fi
      DeleteEverything   # Uninstall product and remove configuration data and database files.
     if [ "$OB2NOEXEC" = 1 ]; then
        rm -rf /var/opt/omni/tmp/omni_tmp
     else
        rm -rf /tmp/omni_tmp
     fi
      exit 0
    fi
  fi
}

ProcessObsolescence()
{
  $Debug
  if [ -f $OMNI_LBIN/inet ]; then
    setDpVersion
    if [ x"$DPOBVersion" != x"" ]; then
      dpMajor=`echo "$(echo $DPOBVersion| cut -d'.' -f 2)" | bc`
      #retaining value of obsolescenceInfo if it is already reset by -accept_obsolescenceInfo option during upgrade
      #from pre 10.00 release
      if [ "$obsolescenceInfo" -ne 0 ]; then
          if [ $dpMajor -ge 10 ]; then
            obsolescenceInfo=0
          else
            obsolescenceInfo=1
          fi
      fi
    fi
  fi
  if [ "$obsolescenceInfo" -ne 1 ]; then
    return
  fi

  if [ -f "$PRODBRANDINGCURRENTDIR/obsolescence.txt" ]; then
    obsolescenceMsg=`cat $PRODBRANDINGCURRENTDIR/obsolescence.txt`
  else
    obsolescenceMsg="      With each Micro Focus Data Protector release, certain software and hardware\n      versions may be obsoleted. For more information about obsoleted combinations,\n      see https://docs.microfocus.com/DP/Obsolescence/DeprecationList.htm. Before\n      you continue with the install or upgrade, review all relevant Data Protector\n      Support Matrices carefully.\n \n \n      If you have any questions or concerns about the obsolescence information,\n      or if you need assistance in understanding the install or upgrade options,\n      please abort the installation/upgrade and contact Micro Focus support.\n"
  fi

  printf "\t\t\t$obsolescenceHeader\n"
  printf "$obsolescenceMsg\n"
  printf "$obsolescenceFooter\n"

  printf "     I understand the changes to the supported platform [Y/E] : "
  while read Answer
	do
	case $Answer in
	   Y|y|yes|Yes|YES)
		   break
	;;
	   E|e)
		   echo "Exiting the installation"
		   exit 0
	;;
	   * )
		   echo "Please provide the correct option (Y/E)"
	;;
	esac
	done
}

ExecutePrereqScript()
{
  if [ -f ${DefaultScriptName} ]; then
    code=`/opt/omni/bin/perl $DefaultScriptName`
    code=$?
    if [ ${code} -ne 0 ]; then
        echo
        echo "  Execution of prerequisite script failed with exit code ${code}. Aborting the installation."
        exit 1
    else
        echo
        echo "  Execution of prerequisite script succeeded. Continuing the installation."
    fi
  fi
}

InitializeVariables()
{ $Debug

  NETSTAT="netstat"
  #### Command netstat is not available in SUSE 15, using ss
  if [ ! -f /usr/bin/${NETSTAT} ]; then
     NETSTAT="ss"
  fi

  if [ "$1" != "-extractpacket" ]; then
  init_var
  fi

  ProcessInput "$@"

  if [ "${MINOR_RELEASE}" = "b1003" ]; then
    echo 
    echo " A.10.03 is a full build. Cannot add/remove using bundleadd/bundlerem options. Please use -CM -IS -install options for installation."
    echo " Exiting... "
    exit 1
  fi
  
  if [ -f /tmp/regencert ]; then
    rm -f /tmp/regencert
  fi
  
  if [ "$Extract" = "Yes" ]; then
    init_var_extract
  fi
  #if [ "$obsolescenceInfo" -eq 1 ]; then
  #  processObsolescence
  #fi
  
  mkdir ${OMNIHOME} 2>/dev/null
  mkdir ${OMNITMP} 2>/dev/null  
    
  if [ -f /usr/omni/config/cell/omni_info ]; then
    OMNICONFIG="/usr/omni/config"
  fi

  if [ "$CellServer" = "" ]; then
    tmp=`cat $OMNICONFIG/client/cell_server 2>/dev/null`

    if [ "$tmp" = "" ]; then                     # effective for versions below 5.5, they had cell_server in cell directory
      tmp=`cat $OMNICONFIG/cell/cell_server 2>/dev/null`
    fi

    if [ "$tmp" = "" ]; then                     # effective for solaris upgrade (config moved from /usr.. to /etc..)
      tmp=`cat /usr/omni/config/cell/cell_server 2>/dev/null`
    fi

    CellServer="$tmp"
    ExistingCellServer="$tmp"
  fi
}

SoftlinkCorrection()
{ $Debug
  CORRECTEDSERIES=$SERIES

  case "${CORRECTEDSERIES}" in
    *sparc/solaris-10)
      case $1 in
        omnicf|da|ma|ndmp)
          CORRECTEDSERIES="sun/sparc/solaris-10"
          ;;
        *)
          CORRECTEDSERIES="sun/sparc/solaris-8"
          ;;
      esac
      ;;
    *solaris-9)
      case $1 in
        da)
          CORRECTEDSERIES="sun/sparc/solaris-9"
          ;;
        *)
          CORRECTEDSERIES="sun/sparc/solaris-8"
          ;;
      esac
      ;;
	*sparc/solaris-8)
      case $1 in
        da)
          CORRECTEDSERIES="sun/sparc/solaris-9"
          ;;
        informix|sap|chs_ls|ndmp|smisa|docs|ssea|ts_core|pegasus|oracle8|integ|jpn_ls|cc|sybase|ma|fra_ls|omnicf)
          CORRECTEDSERIES="sun/sparc/solaris-8"
		  ;;
		*)
          CORRECTEDSERIES="sun/sparc/solaris-10"  
          ;;	  
      esac
      ;;
  esac

  case "${CORRECTEDSERIES}" in
    *s800/hp-ux-113x)
      case $1 in
        da|ma|cc|smisa|ssea|pegasus|ndmp)
          CORRECTEDSERIES="hp/s800/hp-ux-113x"
          ;;
        *)
          CORRECTEDSERIES="hp/s800/hp-ux-11"
          ;;
      esac
      ;;
  esac

  case "${CORRECTEDSERIES}" in
    *sia64/hp-ux-113x)
      case $1 in
        da|ma|cc|smisa|ssea|pegasus|ndmp)
          CORRECTEDSERIES="hp/sia64/hp-ux-113x"
          ;;
        *)
          CORRECTEDSERIES="hp/sia64/hp-ux-11"
          ;;
      esac
      ;;
  esac

  case "${CORRECTEDSERIES}" in
    *sia64/hp-ux-*)
      case $1 in
        docs|jpn_ls|fra_ls|chs_ls)
          CORRECTEDSERIES="hp/s800/hp-ux-11"
          ;;
      esac
      ;;
  esac

  case "${CORRECTEDSERIES}" in
    *linux-oes)
      case $1 in
        omnicf|da)
          CORRECTEDSERIES="gpl/i386/linux-oes"
          ;;
        *)
          CORRECTEDSERIES="gpl/i386/linux-x86"
          ;;
     esac
     ;;
  esac

  case "${CORRECTEDSERIES}" in
    *s390x*)
      case $1 in
        omnicf|da)
          CORRECTEDSERIES="ibm/s390x/zlinux-s390x"
          ;;
     esac
     ;;
  esac

  case "${CORRECTEDSERIES}" in
    *linux-oes-x86-64)
      case $1 in
        omnicf|da)
          CORRECTEDSERIES="gpl/x86_64/linux-oes-x86-64"
          ;;
        *)
          CORRECTEDSERIES="gpl/x86_64/linux-x86-64"
          ;;
      esac
      ;;
  esac

  case "${CORRECTEDSERIES}" in
    *linux*)
      case $1 in
        docs|jpn_ls|fra_ls|chs_ls)
          CORRECTEDSERIES="gpl/x86_64/linux-x86-64"
          ;;          
      esac
      ;;
  esac

}

GetDirectory()
{ $Debug
  PacketDirName=""
case $2 in
  SD4)
  case $1 in 
    omnicf|core)
      PacketDirName=CF-P
      ;;
    ts_core)
      PacketDirName=TS-CF-P
      ;;
    cc)
      PacketDirName=CC-P
      ;;
    da)
      PacketDirName=DA-P
      ;;
    ma)
      PacketDirName=MA-P
      ;;
    integ)
      PacketDirName=INTEG-P
      ;;
    oracle8)
      PacketDirName=OR8-P
      ;;
    sap)
      PacketDirName=SAP-P
      ;;
    sapdb)
      PacketDirName=SAPDB-P
      ;;
    saphana)
      PacketDirName=SAPHANA-P
      ;;
    autodr)
      PacketDirName=AUTODR-P
      ;;
    informix)
      PacketDirName=INF-P
      ;;
    lotus)
      PacketDirName=LOTUS-P
      ;;
    db2)
      PacketDirName=DB2-P
      ;;
    ndmp)
      PacketDirName=NDMP-P
      ;;
    sybase)
      PacketDirName=SYB-P
      ;;
    docs)
      PacketDirName=DOCS-P
      ;;
    jpn_ls)
      PacketDirName=JPN-LS-P
      ;;
    fra_ls)
      PacketDirName=FRA-LS-P
      ;;
    chs_ls)
      PacketDirName=CHS-LS-P
      ;;
    pegasus)
      PacketDirName=TS-PEGASUS-P
      ;;
    smisa)
      PacketDirName=SMISA-P
      ;;
    ssea)
      PacketDirName=SSEA-P
      ;;
    emc)
      PacketDirName=EMC-P
      ;;
    vmwaregre_agent)
      PacketDirName=VMWAREGRE-AGENT-P
      ;;
    vepa)
      PacketDirName=VEPA-P
      ;;
    StoreOnceSoftware)
      PacketDirName=SODA-P
      ;;
    netapp)
      PacketDirName=NETAPP-P
      ;;
    netapp_array)
      PacketDirName=NETAPP_ARRAY
      ;;
    mysql)
      PacketDirName=MYSQL-P
      ;;
    postgresql)
      PacketDirName=POSTGRESQL-P
      ;;
    postgresql_agent)
      PacketDirName=POSTGRESQL_AGENT
     ;;
    mysql_agent)
      PacketDirName=MYSQL-AGENT
     ;;
    dellemcunity)
      PacketDirName=DELLEMCUNITY-P
     ;;
    esac

  SoftlinkCorrection $1
  PacketFullPath=DATA-PROTECTOR/OMNI-$PacketDirName/opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z
    ;;
  SD2)
  case $1 in 
    omnicf|core)
      PacketDirName=CFP
      ;;
    ts_core)
      PacketDirName=TS-CFP
      ;;
    cc)
      PacketDirName=CCP
      ;;
    da)
      PacketDirName=DAP
      ;;
    ma)
      PacketDirName=MAP
      ;;
    integ)
      PacketDirName=INTEGP
      ;;
    oracle8)
      PacketDirName=OR8P
      ;;
    sap)
      PacketDirName=SAPP
      ;;
    sapdb)
      PacketDirName=SAPDBP
      ;;
    saphana)
      PacketDirName=SAPHANAP
      ;;
    autodr)
      PacketDirName=AUTODRP
      ;;
    informix)
      PacketDirName=INFP
      ;;
    lotus)
      PacketDirName=LOTP
      ;;
    db2)
      PacketDirName=DB2P
      ;;
    ndmp)
      PacketDirName=NDMPP
      ;;
    sybase)
      PacketDirName=SYBP
      ;;
    docs)
      PacketDirName=DOCSP
      ;;
    jpn_ls)
      PacketDirName=JPNP
      ;;
    fra_ls)
      PacketDirName=FRAP
      ;;
    chs_ls)
      PacketDirName=CHSP
      ;;
    pegasus)
      PacketDirName=TS-PEGP
      ;;
    smisa)
      PacketDirName=SMISAP
      ;;
    ssea)
      PacketDirName=SSEAP
      ;;
    emc)
      PacketDirName=EMCP
      ;;
    vmwaregre_agent)
      PacketDirName=VMWAREGRE-AGENTP
      ;;
    vepa)
      PacketDirName=VEPAP
      ;;
    StoreOnceSoftware)
      PacketDirName=SODAP
      ;;
    netapp)
      PacketDirName=NETAPPP
      ;;
    netapp_array)
      PacketDirName=NETAPPP_ARRAY
      ;;
    mysql)
      PacketDirName=MYSQLP
      ;;
    postgresql)
      PacketDirName=POSTGRESQLP
      ;;
    postgresql_agent)
      PacketDirName=POSTGRESQLP_AGENT
      ;;
    mysql_agent)
      PacketDirName=MYSQLP_AGENT
      ;;
    dellemcunity)
      PacketDirName=DELLEMCUNITYP
      ;;
    esac

  SoftlinkCorrection $1
  rpm2cpio $TAPEPATH/OB2-$PacketDirName-$VERSION_S-1.x86_64.rpm | cpio -id ./opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z 2>/dev/null 1>&2
  if [ "$package" = "MR" ]; then
    PacketFullPath=opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z
  else
    PacketFullPath=$OMNITMP/opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z
  fi
    ;;
 esac
}

GetDirectoryComp()
{ $Debug
  PacketDirName=""
case $2 in
  SD4)
  case $1 in 
    omnicf|core)
      PacketDirName=CF-P
      ;;
    ts_core)
      PacketDirName=TS-CF-P
      ;;
    cc)
      PacketDirName=CC-P
      ;;
    da)
      PacketDirName=DA-P
      ;;
    ma)
      PacketDirName=MA-P
      ;;
    integ)
      PacketDirName=INTEG-P  
      ;;
    oracle8)
      PacketDirName=OR8-P
      ;;
    sap)
      PacketDirName=SAP-P
      ;;
    sapdb)
      PacketDirName=SAPDB-P
      ;;
    saphana)
      PacketDirName=SAPHANA-P
      ;;
    autodr)
      PacketDirName=AUTODR-P
      ;;
    informix)
      PacketDirName=INF-P
      ;;
    lotus)
      PacketDirName=LOTUS-P
      ;;
    db2)
      PacketDirName=DB2-P
      ;;
    ndmp)
      PacketDirName=NDMP-P
      ;;
    sybase)
      PacketDirName=SYB-P
      ;;
    docs)
      PacketDirName=DOCS-P
      ;;
    jpn_ls)
      PacketDirName=JPN-LS-P
      ;;
    fra_ls)
      PacketDirName=FRA-LS-P
      ;;
    chs_ls)
      PacketDirName=CHS-LS-P
      ;;
    pegasus)
      PacketDirName=TS-PEGASUS-P
      ;;
    smisa)
      PacketDirName=SMISA-P
      ;;
    ssea)
      PacketDirName=SSEA-P
      ;;
    emc)
      PacketDirName=EMC-P
      ;;
    vmwaregre_agent)
      PacketDirName=VMWAREGRE-AGENT-P
      ;;
    vepa)
      PacketDirName=VEPA-P
      ;;
    StoreOnceSoftware)
      PacketDirName=SODA-P
      ;;
    netapp)
      PacketDirName=NETAPP-P
      ;;
    netapp_array)
      PacketDirName=NETAPP_ARRAY
      ;;
    mysql)
      PacketDirName=MYSQL-P
      ;;
    postgresql)
      PacketDirName=POSTGRESQL-P
      ;;
    postgresql_agent)
      PacketDirName=POSTGRESQL_AGENT
      ;;
    mysql_agent)
      PacketDirName=MYSQL-AGENT
      ;;
    dellemcunity)
      PacketDirName=DELLEMCUNITY-P
      ;;
    esac

  SoftlinkCorrection $1
  cd $SrcDir
  if [ "${INSTALL}" = "Clientonly" -o "$package" = "MMR" ]; then
    tar -tf ${hpuxfil} | grep ${CORRECTEDSERIES} | grep ${VERSION} | grep -w $1 > component
    num=`wc -l component | $AWK '{$NF="";sub(/[ \t]+$/,"")}1'`
    if [ $num -eq 1 ]; then
      PacketFullPath=`cat component`
	elif [ "${SERIES}" = "hp/s800/hp-ux-11" -o "${SERIES}" = "hp/sia64/hp-ux-11" ]; then
      read -r PacketFullPath<component  
    else
      echo "Could not locate $1 component in bundle/patch"
   	  rm -rf component
	  exit 1
    fi
    rm -rf component
    tar -xvf ${hpuxfil} ${PacketFullPath}
  elif [ "$PatchAdd" = "Add" -o "$package" = "patchhpux" ]; then
    for X in DP*.depot
    do
	  tar -tf ${X} | grep ${PacketDirName} | grep ${1} | grep ${CORRECTEDSERIES} | grep ${VERSION} > componentpacket
	  if [ -s componentpacket ]; then
	    num4=`wc -l componentpacket | $AWK '{$NF="";sub(/[ \t]+$/,"")}1'`
	    if [ $num4 -eq 1 ]; then
	      PacketFullPath=`cat componentpacket`
	      tar -xvf ${X} ${PacketFullPath}
	      rm -rf componentpacket
	      break
		elif [ "${SERIES}" = "hp/s800/hp-ux-11" -o "${SERIES}" = "hp/sia64/hp-ux-11" ]; then
          read -r PacketFullPath<componentpacket
		  tar -xvf ${X} ${PacketFullPath}
		  rm -rf componentpacket
		  break
        else
	      echo "Could not locate $1 component in bundle/patch"
          exit 1
        fi
	  else
	    rm -rf componentpacket
	    continue
	  fi
    done
  fi
  cd $OMNITMP
    ;;
  SD2)
  case $1 in
    omnicf|core)
      PacketDirName=CORE_Patch
      ;;
    ts_core)
      PacketDirName=CORE_Patch
      ;;
    cc)
      PacketDirName=CC_Patch
      ;;
    da)
      PacketDirName=DA_Patch
      ;;
    ma|ndmp)
      PacketDirName=MA_Patch
      ;;
    integ)
      PacketDirName=CORE_Patch
      ;;
    oracle8)
      PacketDirName=ORACLE8_Patch
      ;;
    sap)
      PacketDirName=SAP_Patch
      ;;
    saphana)
      PacketDirName=SAPHANA_Patch
      ;;
    autodr)
      PacketDirName=AUTODR_Patch
      ;;
    informix)
      PacketDirName=INFORMIX_Patch
      ;;
    sybase)
      PacketDirName=SYBASE_Patch
      ;;
    docs|chs_ls|fra_ls|jpn_ls)
      PacketDirName=DOCS_Patch
      ;;
    pegasus)
      PacketDirName=CORE_Patch
      ;;
    smisa)
      PacketDirName=SMISA_Patch
      ;;
    ssea)
      PacketDirName=SSEA_Patch
      ;;
    vmwaregre_agent)
      PacketDirName=VMWGRE_Patch
      ;;
    vepa)
      PacketDirName=VEPA_Patch
      ;;
    StoreOnceSoftware)
      PacketDirName=SODA_Patch
      ;;
    netapp)
      PacketDirName=NETAPP_Patch
      ;;
    netapp_array)
      PacketDirName=NETAPP_ARRAY_Patch
      ;;
    mysql)
      PacketDirName=MYSQL_Patch
      ;;
    postgresql)
      PacketDirName=POSTGRESQL_Patch
      ;;
    postgresql_agent)
      PacketDirName=POSTGRESQL_AGENT_Patch
      ;;
    mysql_agent)
      PacketDirName=MYSQL_AGENT_Patch
      ;;
    dellemcunity)
      PacketDirName=DELLEMCUNITY_Patch
      ;;
    esac
	
  SoftlinkCorrection $1
  cd $TAPEPATH
  for X in DPLNX*.rpm
  do 
    packetdirname=`rpm -qp --queryformat "%{NAME}\n" $X`
    if [ "$packetdirname" = "$PacketDirName" ]; then
      if [ -z ${package+x} ]; then
        cd $OMNITMP
        rpm2cpio $TAPEPATH/$X | cpio -id ./opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z 2>/dev/null 1>&2
        PacketFullPath=$OMNITMP/opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z
	  else
	    rpm2cpio $TAPEPATH/$X | cpio -id ./opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z 2>/dev/null 1>&2
        PacketFullPath=opt/omni/databases/vendor/$1/$CORRECTEDSERIES/$VERSION/packet.Z
	  fi  
        break
    fi
  done
    ;;
 esac
}

InstallPacket()
{ $Debug

  cd ${OMNITMP}
  FullPacketName $1
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" ]; then
    GetDirectoryComp $1 $SDLabel
  else
  GetDirectory $1 $SDLabel
  fi
  InetPort=$2

  echo "  Installing $PushPacketFullName ($1)..."

  if [ "$SWPackage" = "Yes" ]; then
    PacketPath=$OMNITMP/packet.Z
    if [ -f $SrcDir/$PacketFullPath ]; then 
      cp $SrcDir/$PacketFullPath $OMNITMP
    else
      ErrorHappened=1
    fi  
  else
    PacketPath=$OMNITMP/packet.Z
    if [ -f $TAPEPATH/$PacketFullPath ]; then 
      cp $TAPEPATH/$PacketFullPath $OMNITMP
    elif [ -f $PacketFullPath ]; then 
      cp $PacketFullPath $OMNITMP
    else
      ErrorHappened=1
    fi  
  fi
  
  PacketToInstall=$1
  if [ "$1" = "omnicf" ]; then
    PacketToInstall="core"
  fi

  if [ -f $PacketPath ]; then
	  if [ -f $SrcDir/$hpuxfil ]; then
	      gunzip ${PacketPath}
          mv ${OMNITMP}/packet ${OMNITMP}/packet.Z
	  fi
    ./omni_rinst.sh $PacketPath $PacketToInstall $VERSION $SERIES $OMNIHOME null $InetPort 2>/dev/stdout
    if [ "$?" != "0" ]; then
      ErrorHappened=1
      if [ $PacketToInstall = "core" ]; then
        echo "  Setup cannot continue. Installation of the ${SHORTPRODUCTNAME} CORE component failed."
        exit 1;
      fi
    fi
  else
    echo "    The packet file for this component does not exist."
    echo "    Either it is not supported on this UNIX platform,"
    echo "    an error occurred and the system cannot find"
    echo "    the file $PacketPath, or the installation"
    echo "    has not been started from the appropriate DVD-ROM."
    echo
    ErrorHappened=1
  fi
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" ]; then
    removeFolder=`echo $PacketFullPath | $AWK -F'[/]' '{print $1}'`
    cd $SrcDir
    rm -rf $removeFolder
    cd $OMNITMP
  fi
  # Installation path for 9.x and 10.x versions is different for mac-os.
  # So, 9.x installation path becomes obsolete after installation of 10.x series.
  if [ "$SERIES" = "apple/i386/macos-10.4" -a -d /usr/omni ]; then
    rm -rf /usr/omni
  fi
}

UnpackSelected()
{ $Debug

  if [ "$SWPackage" != "Yes" ]; then
    FilesToUnpack="DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar"

    for Packet in $Packets; do
      GetDirectory $Packet
      FileToUnpack="$PacketFullPath"
      FilesToUnpack="$FilesToUnpack $FileToUnpack"
    done

    cd $OMNITMP

    case $1 in 
     SD4)
       if [ "$package" = "MR" ]; then
	     cp $TAPEPATH/DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar $packetu
	   else
         cp $TAPEPATH/DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar .
	   fi
       ;;
     SD2)
       rpm2cpio $TAPEPATH/OB2-CORE-IS-$VERSION_S-1.x86_64.rpm | cpio -id ./opt/omni/databases/utils/$SERIES/utils.tar 2>/dev/null 1>&2
       if [ "$package" = "MR" ]; then
	     cp $OMNITMP/opt/omni/databases/utils/$SERIES/utils.tar $packetu
		 rm -rf opt/
	   else
         cp ./opt/omni/databases/utils/$SERIES/utils.tar .
	   fi
       ;;
    esac 
  else
    cd $OMNITMP
    if [ "$package" = "MR" ]; then
      cp $SrcDir/DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar $packetu
	else
      cp $SrcDir/DATA-PROTECTOR/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar .
    fi
  fi
}

UnpackSelectedComp()
{ $Debug
    cd $OMNITMP

    case $1 in
     SD4)
	   cd $SrcDir
	   tar -tf ${hpuxfil} | grep ${CorePatch} | grep OMNI-CORE-IS | grep ${SERIES} | grep utils.tar > utilsFolder
	   num1=`wc -l utilsFolder | $AWK '{$NF="";sub(/[ \t]+$/,"")}1'`
       if [ $num1 -eq 1 ]; then
         utilsPath=`cat utilsFolder`
	   elif [ "${SERIES}" = "hp/s800/hp-ux-11" -o "${SERIES}" = "hp/sia64/hp-ux-11" ]; then
         read -r utilsPath<utilsFolder
       else
         echo "Could not locate utils component in bundle/patch"
	     exit 1
       fi
	   rm -rf utilsFolder
	   tar -xvf ${hpuxfil} ${utilsPath}
	   if [ -z ${package+x} ]; then
       cp $TAPEPATH/$CorePatch/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar ${OMNITMP} 
	   else 
	     cp $TAPEPATH/$CorePatch/OMNI-CORE-IS/opt/omni/databases/utils/$SERIES/utils.tar $packetu
	   fi	 
	   rm -rf $CorePatch
       ;;
     SD2)
       rpm2cpio $TAPEPATH/$CorePatch | cpio -id ./opt/omni/databases/utils/$SERIES/utils.tar 2>/dev/null 1>&2
       if [ -z ${package+x} ]; then
       cp ./opt/omni/databases/utils/$SERIES/utils.tar .	   
	   else
         cp ./opt/omni/databases/utils/$SERIES/utils.tar $packetu
	     rm -rf $SrcDir/opt/
	   fi	   
       ;;
    esac
}

PerformInstallation()
{ $Debug
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" ]; then
    GetTapeComp
    UnpackSelectedComp $SDLabel
  else
  GetTape Client
  UnpackSelected $SDLabel
  echo
  fi
  CheckPort
  cd $OMNITMP
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" ]; then
    if [ $SERIES = "hp/s800/hp-ux-11" -o $SERIES = "hp/s800/hp-ux-113x" -o $SERIES = "hp/sia64/hp-ux-11" -o $SERIES = "hp/sia64/hp-ux-113x" ]; then
      gzcat utils.tar | tar -xvf - >/dev/null 2>/dev/null
	else
      tar xvf utils.tar >/dev/null 2>/dev/null	
	fi  
  else
  tar xvf utils.tar >/dev/null 2>/dev/null
  fi
  for Packet in ${Packets}; do
      InstallPacket ${Packet} $PORT
  done
  cd /
}

ImportClient()
{ $Debug

  CellServer2=`cat $OMNICONFIG/client/cell_server 2>/dev/null`
  if [ ! -z "$CellServer2" ]; then
    if [ x"$CellServer" != x"$CellServer2" ]; then
      CellServer=$CellServer2
    fi
  fi

  if [ "$CellServer" = "" ]; then
    echo "  Client was not imported into the cell."
    echo "  Please, perform the import manually by following the steps below."
    echo "    step1: Configure the cell manager by running ${OMNIHOME}/bin/omnicc -secure_comm -configure_peer <Cell Server> from this host."
    echo "    step2: Perform the import manually from cell manager or from one of the other clients of the cell."
    return 2
  fi
  
  cd $OMNIHOME/bin
  HOST_NAME=`hostname | tr "[A-Z]" "[a-z]"`
  if [ "$CellServer" != "$HOST_NAME" ]; then
    if [ "$SERIES" != "apple/i386/macos-10.4" ]; then
      echo "  Configuring secure communication for and importing client to $CellServer..."
      if [ "$NoVerifyPeer" = "Yes" ]; then
        ${OMNIHOME}/bin/omnicc -secure_comm -configure_peer ${CellServer} -accept_host $DebugOpts 2>/dev/stdout
      else
        ${OMNIHOME}/bin/omnicc -secure_comm -configure_peer ${CellServer} $DebugOpts 2>/dev/stdout
      fi
    fi
    ${OMNIHOME}/bin/omnicc -update_host ${HOST_NAME} -server ${CellServer} $DebugOpts 2>/dev/null
    if [ $? != 0 ]; then
      echo
      echo "Client was not imported into the cell."
      echo "  This could be due to this client is not configured for secure communication on the cell manager."
      echo "Please perform the import manually from cell manager or from one of the other clients of the cell."
      return 2
    fi

  fi
}

# IsPacketSelected
#  checks if list $PacketsList contains word $1
#
IsPacketSelected() 
{ $Debug
  for EachPacket in $PacketsList; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
}

IsPacketInstalled()
{ $Debug
  for EachPacket in $InstalledPacketsList; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

IsPacketIntegration()
{ $Debug
  for EachPacket in $IntegrationPackets; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

IsPegasusDepend()
{ $Debug
  for EachPacket in $PegasusDependPackets; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

IsSmisaDepend()
{ $Debug
  for EachPacket in $SmisaDependPackets; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

IsItGoingToBeInstalled()
{ $Debug
  for EachPacket in $Packets; do
    if [ "$EachPacket" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

AskToInstallPacket()
{ $Debug
  if [ "$AskPackets" != "Yes" ]; then
    return 0
  fi

  if [ "$Packet" = "ma" -o "$Packet" = "da" ]; then
    YESNO="YES/no"
  else
    YESNO="yes/NO"
  fi
  # Added option to install netapp_array silently
  if [ "$Packet" = "netapp_array" ]; then
   return 1
  fi
  # Added option to install postgres_agent silently
  if [ "$Packet" = "postgresql_agent" ]; then
   return 1
  fi
  # Added option to install mysql_agent silently
  if [ "$Packet" = "mysql_agent" ]; then
   return 1
  fi

  FullPacketName $1
  echo "  Install ($1) $PushPacketFullName ($YESNO/Quit)?"
  read Answer
  
  if [ "$Answer" = "q" -o "$Answer" = "Q" -o "$Answer" = "quit" -o "$Answer" = "Quit" ]; then
    exit 0
  fi
  
  if [ "$Answer" = "" ]; then
    if [ "$YESNO" = "YES/no" ]; then
      return 1
    else
      return 0
    fi
  else
    if [ "$Answer" = "y" -o "$Answer" = "Y" -o "$Answer" = "Yes" -o "$Answer" = "yes" -o "$Answer" = "YES" ]; then
      return 1
    else
      return 0
    fi
  fi
}

# checks if there anything can be done at the current state.
# if nothing can be done, display message and quit
CheckWork()
{ $Debug
  case "$SERIES" in
    gpl/x86_64/linux-x86-64)
  # CM check - first priority
  if [ "$AddOptCM" = "Yes" -a "$PatchAdd" != "Add" ]; then
        GetDPCMparam
    GetTape CM
    if [ "$TAPEFULLPATH" = "" ]; then
      echo "  Setup cannot continue. Please, insert the installation media with $ARCH Cell Manager"
      echo "  and run the installation script again without options. Setup will then be able to proceed."
      echo 
      TapeMissing="Yes"
    fi
  fi
  
  # IS check
  if [ "$AddOptIS" = "Yes" -a "$PatchAdd" != "Add" ]; then
    GetTape IS
    if [ "$TAPEFULLPATH" = "" ]; then
      echo "  Setup cannot continue. Please, insert the installation media with $ARCH Installation Server"
      echo "  and run the installation script again without options. Setup will then be able to proceed."
      echo 
      TapeMissing="Yes"
    fi  
  fi
     ;;
     *)
     ;;
    esac

  # Client
  if [ "${INSTALL}" = "Clientonly" -o "$PatchAdd" = "Add" -a "${Packets}" != "" ]; then
    GetTapeComp
  elif [ "${Packets}" != "" ]; then
    GetTape Client
    if [ "$TAPEFULLPATH" = "" ]; then
      echo "  Setup cannot continue. Please, insert the installation media with HP-UX Installation"
      echo "  Server and run the installation script again without options. Setup will then be able to proceed."
      echo 
      TapeMissing="Yes"
    fi  
  fi

  if [ "$TapeMissing" = "Yes" ]; then
    exit 1
  else
    if [ "$ExportIDB" = "Yes" -a "$AddOptCM" = "Yes" ]; then
      ExportVelocisIDB
    fi
    return 0
  fi
  
}

SaveCurrentState()
{ $Debug
  rm $TMPIS $TMPCM $TMPClient 2>/dev/null

  if [ "$AddOptCM" = "Yes" ]; then
    echo "Yes" > $TMPCM

#  If Cell Manager has been selected for installation. That means client components 
#  core, ma, da, cc, javagui and docs will be also installed.
#  Remove them from client installation (Packets variable).

    RemoveFromInstallation omnicf ts_core ma da cc docs
  fi
  
  if [ "$AddOptIS" = "Yes" ]; then
    echo "Yes" > $TMPIS
  fi

  if [ "$Packets" != "" ]; then
    echo "$Packets" > $TMPClient
  fi

  if [ "$ErrorHappened" = "1" ]; then
    echo
    echo "  Current state has been saved. Running the setup again without options"
    echo "  will make the script retry the failed operation."
    echo "  Exiting..." 
    exit 1
#  else
#    echo "  Saving current state..."
  fi
}

GetPackets()
{ $Debug

  if [ "$PacketsList" = "" -a "$DPOBVersion" = "" -a "$AddOptCM" != "Yes" -a "$AddOptIS" != "Yes" ]; then    # offer a list of components for installation
# Cycles through all packets and asks if user wants to install the packet
#########################################################################
    for Packet in $PlatformPackets; do
      if [ "$Packet" = "ma" -o "$Packet" = "ndmp" ]; then
        if [ "$MediaAgentSelected" != "Yes" ]; then
          AskToInstallPacket $Packet
          if [ $? = 1 ]; then
            MediaAgentSelected="Yes"
            if [ "$Packets" = "" ]; then
              Packets="$Packet"
            else
              Packets="$Packets $Packet"
            fi
            InstallCore="Yes"
          fi
        fi
      else
        AskToInstallPacket $Packet
        if [ $? = 1 ]; then
          IsPacketIntegration $Packet
          if [ $? = 1 ]; then
            InstallCoreInteg="Yes"
          fi
          IsSmisaDepend  $Packet
          if [ $? = 1 ]; then
            InstallSmisa="Yes"
          fi
          IsPegasusDepend $Packet
          if [ $? = 1 ]; then
            InstallPegasus="Yes"
          fi
          if [ "$Packets" = "" ]; then
            Packets="$Packet"
          else
            Packets="$Packets $Packet"
          fi
          InstallCore="Yes"
        fi
      fi
    done
  else
# Processes input - either in -install option or among installed components 
# or even both
###########################################################################
    for Packet in $PlatformPackets; do
      if [ "$Packet" = "ma" -o "$Packet" = "ndmp" ]; then
        if [ "$MediaAgentSelected" != "Yes" ]; then
          IsPacketSelected $Packet
          if [ $? = 1 ]; then
            if [ "$Packets" = "" ]; then
              Packets="$Packet"
            else
              Packets="$Packets $Packet"
            fi
            MediaAgentSelected="Yes"
            InstallCore="Yes"
          else
            IsPacketInstalled $Packet
            if [ $? = 1 ]; then
              if [ "$Packet" = "ndmp" ]; then
                OldMA=$Packet
                else if [ "$Packet" = "ma" ]; then
                NewMA=$Packet
                fi
              fi
            fi
          fi
        fi
      else
        IsSmisaDepend $Packet
        answer5=$?

        IsPegasusDepend $Packet
        answer4=$?

        IsPacketIntegration $Packet
        answer1=$?

        IsPacketSelected $Packet
        answer2=$?

        IsPacketInstalled $Packet
        answer3=$?

# the next condition (if there was an -install option) determines, whether
# the script must upgrade (reinstall existing components) or install new ones
# for example if there is ma,da,cc components on the host, then
# the command 'omnisetup.sh -install sap' will not reinstall ma,da,cc components
# it will only install sap (or reinstall only it if it was installed before)
#######
        if [ "$PacketsList" != "" -a "$DPOBVersion" = "$VERSION" ]; then
          answer3=0
        fi
          
        if [ "$answer2" = "1" -o "$answer3" = "1" ]; then
          if [ "$Packets" = "" ]; then
            Packets="$Packet"
          else
            IsItGoingToBeInstalled $Packet
            pkgInList=$?
            if [ $pkgInList = 0 ]; then
              Packets="$Packets $Packet"
            fi
          fi
          InstallCore="Yes"
          IsNDMPInstalled
          for PACK in $InstalledNDMP; do
            if [ "$PACK" = "ndmp" ]; then
              NDMPInstalled="Yes"
            fi
          done
          InstalledNDMP=""
          if [ $answer4 = 1 ]; then
            InstallPegasus="Yes"
          fi

          if [ $answer5 = 1 ]; then
            InstallSmisa="Yes"
          fi
          
          if [ $answer1 = 1 ]; then
            InstallCoreInteg="Yes"
          fi
        fi
      fi
    done
    if [ "$MediaAgentSelected" != "Yes" -a \( "$OldMA" != "" -o "$NewMA" != "" \) -a \( "$PacketsList" = "" -o "$DPOBVersion" != "$VERSION" \) ]; then
      InstallCore="Yes"
      Packets="$NewMA $OldMA $Packets"
    fi
  fi

  if [ "$InstallPegasus" = "Yes" ]; then
    Packets="pegasus $Packets"
  fi

  if [ "$InstallSmisa" = "Yes" ]; then
    Packets="smisa $Packets"
  fi

  if [ "$InstallCoreInteg" = "Yes" ]; then
    Packets="integ $Packets"
  fi

  if [ "$InstallCore" = "Yes" ]; then
    Packets="omnicf ts_core $Packets"
  fi
}

PreparePacketList()
{ $Debug
  for Packet in $CorrectPackets; do
    PacketString=`grep "\-key $Packet " $OLDOMNIINFO`
    if [ "$PacketString" != "" ]; then
      PacketsList="$PacketsList $Packet"
    fi
  done
}

CheckVelocisDatabaseIsExported()
{ $Debug
  export_ok=`grep "STATUS=OK" /var/opt/omni/server/exported/omnimigrate_chk 2>/dev/null`
  if [  x"$export_ok" != x"" ]; then
    echo "  An exported Internal Database found. It will be upgraded."
  else
    echo "  Setup cannot continue, as the existing Internal Database has not been exported."
    echo "  For the upgrade procedure, see the Installation and Licensing Guide."
    echo "  Exiting..."
    exit 1
  fi
}

ExportVelocisIDB()
{ $Debug
  echo "  Exporting ${SHORTPRODUCTNAME} IDB"

  RunRDS=`$OMNIHOME/sbin/omnisv status 2>/dev/null |grep rds |grep Active`
  if [ x"$RunRDS" != x"" ]; then
    echo "  RDS service running." 

    mkdir -p /var/opt/omni/server/exported
    case "${SERIES}" in 
     gpl/x86_64/linux-x86-64)
        OSPWD=`pwd`
        cd $OMNITMP
        rpm2cpio $OSPWD/linux_x86_64/DP_DEPOT/OB2-CS-$VERSION_S-1.x86_64.rpm | cpio -id ./opt/omni/sbin/omnimigrate.pl 2>/dev/null 1>&2
        cd - > /dev/null
        $OMNIHOME/bin/perl $OMNITMP/opt/omni/sbin/omnimigrate.pl -shared_dir /var/opt/omni/server/exported -export
        PPP=$?
        ;;
      *)
        echo "  Upgrade of the Cell Manager on this platform is not supported."
        ;;
    esac

    if [ "$PPP" = "0" ]; then
       echo "  Exporting DONE!"
    else
      echo "  IDB Export FAILED!"
      exit 1
    fi

  else
    echo "  RDS service is not running. Check if the Internal Database has been exported."
    CheckVelocisDatabaseIsExported
    echo "  Exporting DONE!"
  fi

}

GatherInstalledPackets()
{ $Debug

  case "$DPOBVersion" in
    A\.0[6789]*|A\.10\.*|X\.34\.*|X\.35\.*|X\.99\.*)
      for iPacket in $CorrectPackets; do
        PacketVersion=`echo "$OLDOMNIINFO" 2>/dev/null | grep "\-key $iPacket "`
        STR_PACKET=" $iPacket "
        if [ $iPacket = "mysql" ]; then
          iPacket="mysql_agent"
        elif [ $iPacket = "netapp" ]; then
          iPacket="netapp_array"
        elif [ $iPacket = "postgresql" ]; then
          iPacket="postgresql_agent"
        fi
        if [ "$PacketVersion" != "" ] ;then
           if [ "$InstalledPacketsList" = "" ]; then
              InstalledPacketsList="$InstalledPacketsList $iPacket "
           elif test "${InstalledPacketsList#*$STR_PACKET}" = "$InstalledPacketsList" ; then
              InstalledPacketsList="$InstalledPacketsList$iPacket "
           fi
        fi
      done
      ;;
  esac
}

IsNDMPInstalled()
{ $Debug

  case "$DPOBVersion" in
    A\.0[6789]*|A\.10\.*|X\.34\.*|X\.35\.*|X\.99\.*)
      for iPacket in $CorrectPackets; do
        PacketVersion=`echo "$OLDOMNIINFO" 2>/dev/null | grep "\-key $iPacket "`
        if [ "$PacketVersion" != "" ]; then
          InstalledNDMP="$InstalledNDMP $iPacket"
        fi
      done
      ;;
  esac
}

DisplayVersionInstalled()
{ $Debug
  case "$DPOBVersion" in
    A\.08\.00|A\.08\.10|A\.09\.00|A\.09\.10|A\.10\.00|A\.10\.03|A\.10\.10|A\.10\.20|A\.10\.30|A\.10\.40|A\.10\.50|A\.10\.60|A\.10\.70|A\.10\.80|A\.10\.90|A\.10\.91|X\.34\.01|X\.35\.01|X\.99\.01|X\.99\.02)
      echo
      echo "  ${SHORTPRODUCTNAME} version $DPOBVersion found"
      InstalledProductCode="DATA-PROTECTOR"
      InstalledProductName="${BRIEFPRODUCTNAME}"
      ;;
    A\.06\.11|A\.06\.20|A\.06\.21|A\.07\.00)
      echo
      echo "  ${SHORTPRODUCTNAME} version $DPOBVersion found"
      InstalledProductCode="DATA-PROTECTOR"
      InstalledProductName="${BRIEFPRODUCTNAME}"
      ExportIDB="Yes"
      ;;
    *)
      echo
      echo "  Setup has detected version $DPOBVersion of $DPOBProduct."
      
      currVer=`echo $VERSION | sed s/A.// | bc`
      
      IsDPOBVersionlessThan $currVer
      if [ "$?" = 1 ]; then
          echo "  Upgrade from this version is not supported."
          echo "  The earliest supported release version that can be upgraded is $DPOBProduct A.06.11."
      else
          echo "  Downgrade from higher version is not supported."
      fi

      echo "  Exiting..."
      echo
      exit 1
      ;;
  esac
  if [ "${INET_PORT}" != "" ]; then
        echo "  INET port cannot be changed during upgrade"
        echo "  Continuing installation with existing INET port"
        INET_PORT=""
  fi 
  
  if [ -f "$OMNI_LBIN/mmd" ]; then
    echo "  Cell Manager detected..."
    CMUpgrade="Yes"
  fi

  if [ -f "$OMNI_LBIN/bmsetup" ]; then
    echo "  Installation Server detected..."
  fi

  if [ "$InstalledPacketsList" != "" ]; then
    echo "  Client detected, installed components: $InstalledPacketsList"
  fi

  echo
}

GatherInstalledParts()
{ $Debug
  DisplayVersionInstalled

  if [ "$Uninstall" = "Yes" -o "$Reinstall" = "Yes" ]; then
  if [ -f "$OMNI_LBIN/mmd" ]; then
      AddOptCM="Yes"
    fi

    if [ -f "$OMNI_LBIN/bmsetup" ]; then
      AddOptIS="Yes"
    fi
  fi
}

CheckSavedState()
{ $Debug
  if [ -f $TMPClient -o -f $TMPIS -o -f $TMPCM ]; then
    echo
    echo "  The omnisetup.sh script did not complete the last time it was run."
    if [ -f $TMPCM ]; then
      echo "  Cell Manager still has to be installed"
    fi

    if [ -f $TMPClient ]; then
      echo '  Client still has to be installed. ('`cat $TMPClient`')'
    fi

    if [ -f $TMPIS ]; then
      echo "  Installation Server still has to be installed"
    fi

    echo

    echo "  The omnisetup.sh script can now resume the installation session"
    echo "  or it can ignore the saved state and start a new session."
    echo "  If you choose to ignore, the script will erase the saved state"
    echo "  and will process only the command line options."
    echo "  Do you want the setup to resume the installation? [Y/N] :"
    read Answer
    if [ "$Answer" = "" -o "$Answer" = "Y" -o "$Answer" = "y" -o "$Answer" = "YES" -o "$Answer" = "yes" ]; then
      echo "  Resuming (using the specified CLI options)..."
      if [ -f $TMPCM ]; then
        AddOptCM="Yes"
      fi

      if [ -f $TMPClient ]; then
        PacketsList="$PacketsList "`cat $TMPClient`
      fi

      if [ -f $TMPIS ]; then
        AddOptIS="Yes"
      fi
    else
      rm $TMPClient $TMPIS $TMPCM 2>/dev/null
      echo "  Ignoring saved state..."
    fi
    echo
  fi
}

CheckDatabase()
{ $Debug

  OMNI_CDB=/var${OMNIHOME}/db/cdb
  DB_VERS=/var${OMNIHOME}/db/catalog/version.txt
  DB_VERS40=/var${OMNIHOME}/db40/datafiles/catalog/version.txt
  DB_VERS55=/var${OMNIHOME}/server/db40/datafiles/catalog/version.txt
  DB_VERS70=/etc${OMNIHOME}/server/idb/version.txt

  # version.txt has hardcoded (not branded!) product strings (see CC:/ob/src/lib/cmn/defines.h)
  # For DP:    "HP OpenView OmniBack II"
  # For APPRM: "HP Application Recovery Manager"
  # after this the version string follows: "A.06.10"

  # check for current database version 
  if [ -f "$DB_VERS70" ]; then
    #DB_PRODUCT=`$AWK '{sub(" +A.[0-9].*",""); sub(" +X.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub(" +software",""); sub("OmniBack II", "Data Protector"); print}' $DB_VERS70`
    DB_VERSION_STR=`$AWK '{sub("HP OpenView OmniBack II +",""); sub("HP( StorageWorks | )Application Recovery Manager +",""); print}' $DB_VERS70`
    DB_VERSION=${DB_VERSION_STR#A.}; DB_VERSION=${DB_VERSION#X.}; DB_VERSION=${DB_VERSION#0}; DB_VERSION=${DB_VERSION%%.\%*}
#   echo "NOTE:    $DB_PRODUCT Internal Database version $DB_VERSION_STR found."
  else
  if [ -f "$DB_VERS55" ]; then
    #DB_PRODUCT=`$AWK '{sub(" +A.[0-9].*",""); sub(" +X.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub(" +software",""); sub("OmniBack II", "Data Protector"); print}' $DB_VERS55`
    DB_VERSION_STR=`$AWK '{sub("HP OpenView OmniBack II +",""); sub("HP( StorageWorks | )Application Recovery Manager +",""); print}' $DB_VERS55`
    DB_VERSION=${DB_VERSION_STR#A.}; DB_VERSION=${DB_VERSION#X.}; DB_VERSION=${DB_VERSION#0}; DB_VERSION=${DB_VERSION%%.\%*}
#   echo "NOTE:    $DB_PRODUCT Internal Database version $DB_VERSION_STR found."

  else
    # detect older database version 4.00 4.10 5.00 5.10
    if [ -f "$DB_VERS40" ]; then
      #DB_PRODUCT=`$AWK '{sub(" +A.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub(" +software",""); sub("OmniBack II", "Data Protector"); print}' $DB_VERS40`
      DB_VERSION_STR=`$AWK '{sub("HP OpenView OmniBack II +",""); sub("HP( StorageWorks | )Application Recovery Manager +",""); print}' $DB_VERS40`
      DB_VERSION=${DB_VERSION_STR#A.}; DB_VERSION=${DB_VERSION#0}; DB_VERSION=${DB_VERSION%%.\%*}
#     echo "NOTE:    $DB_PRODUCT Internal Database version $DB_VERSION_STR found."

    else
      # detect very old database version 3.51 3.50 3.10 3.00 2.55
      if [ -d "$OMNI_CDB" ]; then
        if [ -f "$DB_VERS" ]; then
          #DB_PRODUCT=`$AWK '{sub(" +A.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub(" +software",""); sub("OmniBack II", "Data Protector"); print}' $DB_VERS`
          DB_VERSION_STR=`$AWK '{sub("HP OpenView OmniBack II +",""); sub("HP( StorageWorks | )Application Recovery Manager +",""); print}' $DB_VERS`
          DB_VERSION=${DB_VERSION_STR#A.}; DB_VERSION=${DB_VERSION#0}; DB_VERSION=${DB_VERSION%%.\%*}
#         echo "NOTE:    $DB_PRODUCT Internal Database version $DB_VERSION_STR found."

        else
          #DB_PRODUCT=OmniBack
          DB_VERSION=OLD
        fi

      else
        #DB_PRODUCT=""
        DB_VERSION=0
      fi
    fi
  fi
  fi

  case $DB_VERSION in
    0)
      # OK (fresh install)
      ;;

    6.11|6.20|6.21|7.00)
      echo "NOTE:    Internal Database version $DB_VERSION_STR found."
      CheckVelocisDatabaseIsExported
      ;;

    8.00|8.10|9.00|10.00|10.03|10.04|10.10|10.20|10.30|10.40|10.50|10.60|10.70|10.80|10.90|10.91|34.01|35.01|99.01|99.02)
      echo "NOTE:    Internal Database version $DB_VERSION_STR found."
      ;;

    *)
       # Unsupported version
       echo 
       echo "  Unknown/unsupported Internal Database version $DB_VERSION_STR detected."
       echo "  ${SHORTPRODUCTNAME} software can not function properly with this"
       echo "  database. For a manual upgrade procedure, see the user documentation."
       echo 
       exit 1
      ;;
  esac
}
#it will identify which components are installed in MR and
#will only upgrade those components when MMR will run
CreateCompPacketsList()
{ $Debug

  cd ${OMNIHOME}
  `ls -la | grep .patch_ > component_file`
  `$AWK 'NF{ print $NF }' component_file > components`
  FILE=components
  end_of_file=0
  while [ $end_of_file -eq 0 ]
  do
    read -r word
    end_of_file=$?
	if [ $end_of_file -ne 0 ]; then
	  break
	fi
	wordLength=`echo $word | wc -m`
	wordLength=`expr $wordLength - 1 `
	compPacket=`echo $word | cut -c8-$wordLength`
	if [ "$compPacket" != "core" -a "$compPacket" != "ts_core" ]; then
	  PacketsList="$PacketsList $compPacket"
	fi
  done < "$FILE"
  rm -rf component_file components
  cd ${SrcDir}
}
# set DPOBVersion if DP already installed.
setDpVersion()
{
  DPOBVersion=`$OMNI_LBIN/inet -ver 2>/dev/null | $AWK '{for(i=1;i<=NF;i+=1) {print $i}}' | grep "[A|X]\.[0-9]" | tr -d ": "`
  # Installation path for 9.x and 10.x versions is different for mac-os. So, check 9.x installation path also for version.
  if [ "$DPOBVersion" = "" -a "$SERIES" = "apple/i386/macos-10.4" -a -d /usr/omni ]; then
    DPOBVersion=`/usr/omni/bin/inet -ver 2>/dev/null | $AWK '{for(i=1;i<=NF;i+=1) {print $i}}' | grep "[A|X]\.[0-9]" | tr -d ": "`
  fi
}
# CheckTasks checks if there are any unfinished jobs from previous installations
# if no, then checks which components are installed and ask user what he wants
CheckTasks()
{ $Debug

  if [ "$Extract" != "Yes" ]; then
  CheckSavedState
  fi

  DPOBVersion=`$OMNI_LBIN/inet -ver 2>/dev/null | $AWK '{for(i=1;i<=NF;i+=1) {print $i}}' | grep "[A|X]\.[0-9]" | tr -d ": "`
  # Installation path for 9.x and 10.x versions is different for mac-os. So, check 9.x installation path also for version.
  if [ "$DPOBVersion" = "" -a "$SERIES" = "apple/i386/macos-10.4" -a -d /usr/omni ]; then
    DPOBVersion=`/usr/omni/bin/inet -ver 2>/dev/null | $AWK '{for(i=1;i<=NF;i+=1) {print $i}}' | grep "[A|X]\.[0-9]" | tr -d ": "`
  fi
  
  # Skipping below check for DP 'A.10.91', as the sed command converting version from 'A.10.91' to 'A.10.90' which is causing reporting server installation failure
  if [ "$DPOBVersion" != "A.10.03" ] && [ "$DPOBVersion" != "A.10.91" ]; then
      DPOBVersion=`echo $DPOBVersion | sed s/./0/7`
  fi
  DPOBProduct=`$OMNI_LBIN/inet -ver 2>/dev/null | $AWK '{sub(" +A.[0-9].*",""); sub(" +X.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub("Storage +", ""); sub(" +software",""); print}'`

# check whether auto-migration needed or not.
# Platforms other than HP-UX, upgrade will first uninstall and then install
# hence checking it before uninstall.
# Auto-Migration of keys for the CM while upgrade from 6.0 to 6.1

  AutoMigrate="No"
  DPOBVersion_S=`echo $DPOBVersion | $AWK -F"." '{ print $1  "."  $2 "." $3 }'`
  if [ "$DPOBVersion_S" = "A.06.00" ]; then
    if [ -f ${OMNIHOME}/bin/omnikeytool ]; then
        AutoMigrate="Yes"
    fi
  fi

  case $SERIES in 
    sun*|gpl*|*s390x*)
      if [ "$DPOBVersion" = "" ]; then
        DPOBVersion=`/usr/omni/*bin/inet -ver 2>/dev/null | $AWK '{for(i=1;i<=NF;i+=1) {print $i}}' | grep "A\.[0-9]" | tr -d ": "`
        if [ "$DPOBVersion" != "A.10.03" ]; then
          DPOBVersion=`echo $DPOBVersion | sed s/./0/7`
        fi
      fi
      if [ "$DPOBProduct" = "" ]; then
        DPOBProduct=`/usr/omni/*bin/inet -ver 2>/dev/null | $AWK '{sub(" +A.[0-9].*",""); sub("HP +",""); sub("(OpenView|StorageWorks) +",""); sub("Storage +", ""); sub(" +software",""); print}'`
      fi
      ;;
  esac
  if [ "$Extract" != "Yes" ]; then
    if [ "$DPOBVersion" = "" ]; then
      echo "  No ${SHORTPRODUCTNAME} software detected on the target system."
      echo
      CheckDatabase
      if [ "$Reinstall" = "Yes" ]; then
        echo "  Reinstallation cannot be performed. Wrong CLI option specified."
        echo "  Exiting..."
        exit 1
      fi

      if [ "$Option" != "Yes" ]; then
        AskPackets=Yes
      fi 
    else
      if [ "$SUBPRODUCT" = "AppRM" -a "$DPOBProduct" != "Application Recovery Manager" ]; then
        echo "  Installation of AppRM has detected ${BRIEFPRODUCTNAME} version $DPOBVersion"
        echo "  on the system. Upgrade from ${BRIEFPRODUCTNAME} is not supported."
        echo "  Please uninstall it first before continuing with AppRM installation."
        echo "  Exiting..."
        exit 1
      fi

      GatherInstalledPackets
      case "$DPOBVersion" in 
        "$VERSION")
          Uninstall=No
           if [ "$Reinstall" = "Yes" ]; then
             GatherInstalledParts
           else
             if [ "$Packets" = "" -a "$PacketsList" = "" ]; then
               AskPackets=Yes
             fi
             DisplayVersionInstalled
             InstalledPacketsList=""
           fi
          ;;
        *)
          Uninstall=Yes
          if [ ! -f $OMNITMP/socket.dat ]; then
            if [ "$DPOBVersion" != "" -a "$DPOBVersion" != "$VERSION" ]; then
              cat "/etc/services" | sed -e 's/[   ]/ /g' | egrep "^omni + *" |  awk '{print $2}' | uniq | tr "\/" " " | awk '{print $1}' > $OMNITMP/socket.dat
            fi
          fi
          GatherInstalledParts
          case "$DPOBVersion" in 
            A\.0[45]*)
              case $SERIES in
              gpl*|*s390x*)
                 echo "Files from an earlier version are found in /usr/omni. These will be moved"  
                 echo "to /var/opt/omni/tmp/usr_omni. If you have customized files in this directory tree"  
                 echo "then they can still be retrieved from the temporary directory tree."  
                 ;;
              esac
              ;;
          esac

          ;;
      esac
    fi
  fi

  GetPackets

  if [ "$AddOptCM" != "Yes" -a "$AddOptIS" != "Yes" -a "$Packets" = "" -a "$AddOptRS" != "Yes" ]; then
    echo "  omnisetup.sh has nothing to process, exiting..."
    exit 1
  fi

# FURPS Id FDR24934:  do not uninstall DP/OB during upgrade on HPUX
  case $SERIES in 
    hp*)
      Uninstall=No
      ;;
  esac
}

# this function gets an option - which object is going to be installed (CM, CL, IS)
# it must output the filename of a tape from which the object can be installed
GetTape()
{ $Debug

  OldDir=`pwd`
  if [ "$OB2NOEXEC" = 1 ]; then
     mkdir -p /var/opt/omni/tmp/omni_tmp/tmp 2>/dev/null
     cd /var/opt/omni/tmp/omni_tmp/tmp
  else
     mkdir /tmp/omni_tmp/tmp 2>/dev/null
     cd /tmp/omni_tmp/tmp
  fi

  TAPEFULLPATH=""
  Tapes=`echo $TapePlatforms | $AWK '{for(i=2; (i<=NF); i+=6) {print $i}}'`
  SDLabels=`echo $TapePlatforms | $AWK '{for(i=1; (i<=NF); i+=6) {print $i}}'`
  paths=`echo $TapePlatforms | $AWK '{for(i=6; (i<=NF); i+=6) {print $i}}'`
  case $1 in
    CM)
      Choices=`echo $TapePlatforms | $AWK '{for(i=3; (i<=NF); i+=6) {print $i}}'`
      ;;
    Client)
      Choices=`echo $TapePlatforms | $AWK '{for(i=4; (i<=NF); i+=6) {print $i}}'`
      ;;
    IS)
      Choices=`echo $TapePlatforms | $AWK '{for(i=5; (i<=NF); i+=6) {print $i}}'`
      ;;
  esac
  
  # Tapes are tape filenames and Choices are the values where we must find matching value
  # get it's number and output this number's tape filename
  counter=0;
  TapeCount="";
  for Choice in $Choices; do
    counter=`echo $counter | $AWK '{print $1+1}'`
    if [ "$Choice" = "All" ]; then
      TapeCount="$counter $TapeCount"
	elif [ "$Extract" = "Yes" ]; then
	  TapeCount="$counter $TapeCount"
    else
      case ${SERIES} in
        $Choice)
          TapeCount="$counter $TapeCount"
          ;;
      esac
    fi
  done
  
  cd $OldDir
  if [ "$OB2NOEXEC" = 1 ]; then
     rm -rf /var/opt/omni/tmp/omni_tmp/tmp 2>/dev/null
  else
     rm -rf /tmp/omni_tmp/tmp 2>/dev/null
  fi

  for TapeCounter in $TapeCount; do
    Tape=`echo $TapeCounter $Tapes | $AWK '{print $($1+1)}'`
    SDLabel=`echo $TapeCounter $SDLabels | $AWK '{print $($1+1)}'`
    path=`echo $TapeCounter $paths | $AWK '{print $($1+1)}'`

    CheckTapeExistence $Tape $path
    if [ "$TAPEFULLPATH" != "" ]; then 
      return 1
    fi
  done
  
# if the tape was not found, check for uncompressed sw depot
  case $SERIES in
    hp*)
      if [ "$TAPEFULLPATH" = "" ]; then
        case $1 in
          CM)
            if [ -d "$SrcDir/DATA-PROTECTOR/OMNI-CS" ]; then
              TAPEFULLPATH=$SrcDir
              SWPackage=Yes
            fi
            ;;
          IS|Client)
            if [ -d "$SrcDir/DATA-PROTECTOR/OMNI-CORE-IS" ]; then
              TAPEFULLPATH=$SrcDir
              SWPackage=Yes
            fi
            ;;
        esac
      fi
      ;;
  esac
      if [ "$TAPEFULLPATH" = "" -a "$1" = "Client" ]; then
            if [ -d "`pwd`/$SW_DEPOT/DATA-PROTECTOR/OMNI-CORE-IS" ]; then
              SrcDir=`pwd`/$SW_DEPOT
              TAPEFULLPATH=$SrcDir
              SWPackage=Yes
            fi
      fi
}
#it first check, if DPUX[HPUX] or DPLNX is present in SrcDir; then looks for CORE_Patch in same.
#It must output the filename of a tape from which the object can be installed (Can be HPUX or Linux)
GetTapeComp()
{ $Debug

  OldDir=`pwd`
  hpuxpattern=".depot"
  lnxpattern="DPLNX"
  for _file in *"${hpuxpattern}"*; do
    [ -f "${_file}" ] && hpuxfil="${_file}" && break
  done
  for _fil in *"${lnxpattern}"*; do
    [ -f "${_fil}" ] && lnxfil="${_fil}" && break
  done
    if [ -f $SrcDir/$hpuxfil ]; then
	  if [ ${INSTALL} = "Clientonly" -o "$package" = "MMR" ]; then
        flag=0
	    tar -tf ${hpuxfil} | grep OMNI-CORE-IS | grep utils | grep ${SERIES} > folder
		if [ $? -eq 0 ]; then
		  flag=1
		fi
		num2=`wc -l folder | $AWK '{$NF="";sub(/[ \t]+$/,"")}1'`
        if [ $num2 -eq 1 ]; then
		  direc=`cat folder`
		elif [ "${SERIES}" = "hp/s800/hp-ux-11" -o "${SERIES}" = "hp/sia64/hp-ux-11" ]; then
          read -r direc<folder
		else
		  echo "Could not locate Core component in bundle/patch"
 	      exit 1
		fi
		CorePatch=`echo $direc | $AWK -F'[/]' '{print $1}'`
	    TapePlatformsComp="SD4 $hpuxfil 0 All hp* hpux"
		rm -rf folder
	    if [ $flag -eq 0 ]; then
	    echo "Core patch is not present, cannot proceed with installation"
	    echo "Installation unsuccessful"
	    exit 1;
        fi
	  elif [ "$PatchAdd" = "Add" -o "$package" = "patchhpux" ]; then  
	    flag=0
		  for X in DP*.depot
		  do
		    tar -tf ${X} | grep OMNI-CORE-IS | grep utils | grep ${SERIES}
			  if [ $? -eq 0 ]; then
			    tar -tf ${X} | grep OMNI-CORE-IS | grep utils | grep ${SERIES} > depotName
				num3=`wc -l depotName | $AWK '{$NF="";sub(/[ \t]+$/,"")}1'`
				if [ $num3 -eq 1 ]; then
				  Coredirec=`cat depotName`
				  hpuxfil=$X
				  flag=1
				elif [ "${SERIES}" = "hp/s800/hp-ux-11" -o "${SERIES}" = "hp/sia64/hp-ux-11" ]; then
                  read -r Coredirec<depotName
				  hpuxfil=$X
				  flag=1
				else
				  echo "Could not locate Core component in bundle/patch"
				  exit 1
				fi 
				CorePatch=`echo $Coredirec | $AWK -F'[/]' '{print $1}'`
				TapePlatformsComp="SD4 $hpuxfil 0 All hp* hpux"
				rm -rf depotName
				break		  
			  fi
		  done
		  if [ $flag -eq 0 ]; then
            echo "Core Component is not present, cannot proceed with the installation"
            exit 1
          fi	
	  fi
  elif [ -f $lnxfil ]; then
    flag1=0
	for X in DPLNX*.rpm
	do
	if [ "`rpm -qp --queryformat "%{NAME}\n" $X | grep -w CORE_Patch`" = "CORE_Patch" ]; then
      CorePatch=$X
	  TapePlatformsComp="SD2 $CorePatch 0 *linux* gpl* linux_x86_64"
	  flag1=1
      break
	  fi
      done
	  if [ $flag1 -eq 0 ]; then
	  echo "Core patch is not present, cannot proceed with installation"
	  echo "Installation unsuccessful"
	  exit 1;
      fi
  fi  
  
  TAPEFULLPATH=""
  Tapes=`echo $TapePlatformsComp | $AWK '{for(i=2; (i<=NF); i+=6) {print $i}}'`
  SDLabels=`echo $TapePlatformsComp | $AWK '{for(i=1; (i<=NF); i+=6) {print $i}}'`
  paths=`echo $TapePlatformsComp | $AWK '{for(i=6; (i<=NF); i+=6) {print $i}}'`
  Choices=`echo $TapePlatformsComp | $AWK '{for(i=4; (i<=NF); i+=6) {print $i}}'`
  
  # Tapes are tape filenames and Choices are the values where we must find matching value
  # get it's number and output this number's tape filename
  counter=0;
  TapeCount="";
  for Choice in $Choices; do
    counter=`echo $counter | $AWK '{print $1+1}'`
    if [ "$Choice" = "All" ]; then
      TapeCount="$counter $TapeCount"
	elif [ "${Extract}" = "Yes" ]; then
	  TapeCount="$counter $TapeCount"
    else
      case ${SERIES} in
        $Choice)
          TapeCount="$counter $TapeCount"
          ;;
      esac
    fi
  done
  
  cd $OldDir

  for TapeCounter in $TapeCount; do
    Tape=`echo $TapeCounterComp $Tapes | $AWK '{print $($1+1)}'`
    SDLabel=`echo $TapeCounterComp $SDLabels | $AWK '{print $($1+1)}'`
    path=`echo $TapeCounterComp $paths | $AWK '{print $($1+1)}'`

    CheckTapeExistence $Tape $path
    if [ "$TAPEFULLPATH" != "" ]; then 
      return 1
    fi
  done
}

CheckCMSystemReq()
{ $Debug
  case "$SERIES" in
    gpl*|*s390x*)
      if [ -f /etc/redhat-release ]; then
        rh_ver6=`rpm -qa | grep "release-server-6"`
        if [ "$rh_ver6" != "" ]; then
          glibc32=`rpm -qa | grep "glibc-[0-9]" | grep i686`
          if [ "$glibc32" = "" ]; then
            echo "  Error:    To be able to install ${SHORTPRODUCTNAME} Cell Manager on this platform,"
            echo "            glibc-2.12-1.25.el6.i686 or a later version must be installed on the system."
            checkCM=1
          else
            echo "  Passed:   Package $glibc32 is installed on the system."
          fi
          return
        fi
        rh_ver7=`rpm -qa | grep "release-server-7"`
        if [ "$rh_ver7" != "" ]; then
          glibc32=`rpm -qa | grep "glibc-[0-9]" | grep i686`
          if [ "$glibc32" = "" ]; then
            echo "  Error:    To be able to install ${SHORTPRODUCTNAME} Cell Manager on this platform,"
            echo "            glibc-x.xx-xx.el7.i686 must be installed on the system."
            checkCM=1
          else
            echo "  Passed:   Package $glibc32 is installed on the system."
          fi
          return
        fi

        rh_ver8=`rpm -qa | grep "release-8"`
        if [ "$rh_ver8" != "" ]; then
          glibc=`rpm -qa | grep "glibc-[0-9]"|grep x86_64`
          if [ "$glibc" = "" ]; then
            echo "  Error:    To be able to install ${SHORTPRODUCTNAME} Cell Manager on this platform,"
            echo "            glibc-x.xx-xx.xx must be installed on the system."
            checkCM=1
          else
            echo "  Passed:   Package $glibc is installed on the system."
          fi
          
          libnsl=`rpm -qa | grep "libnsl-"`
          if [ "$libnsl" = "" ]; then
            echo "  Error:    To be able to install ${SHORTPRODUCTNAME} Cell Manager on this platform,"
            echo "            libnsl-2.xx-xx.el8.x86_64 must be installed on the system."
            checkCM=1
          else
            echo "  Passed:   Package $libnsl is installed on the system."
          fi

          return
        fi
      fi
      ;;
      *)
      ;;
  esac
}

GetDPCMparam()
{ $Debug

ParamFile=${OMNIHOME}/newconfig/${OMNICONFIG}/client/customize/dp_param
IDBConf=${OMNICONFIG}/server/idb/idb.config
DPdat=$OMNITMP/DP.dat
APPS_STANDALONE_FILE=${OMNICONFIG}/server/AppServer/standalone.xml

if [ -f ${IDBConf} ]; then
  if [ x${PGPORT} = x"" ]; then
    PGPORT=`cat ${IDBConf} |grep PGPORT | $AWK -F"'" '{ print $2 }'`
  fi
  if [ x${PGCPPORT} = x"" ]; then
    PGCPPORT=`cat ${IDBConf} |grep PGCPPORT | $AWK -F"'" '{ print $2 }'`
  fi
  if [ x${PGOSUSER} = x"" ]; then
    PGOSUSER=`cat ${IDBConf} |grep PGOSUSER | $AWK -F"'" '{ print $2 }'`
  fi
  #Probably reinstall...
  if [ -f ${APPS_STANDALONE_FILE} ]; then
    if [ x${APPSNATIVEMGTPORT} = x"" ]; then
      #Parse port from: <socket-binding name="management-native" interface="management" port="${jboss.management.native.port:9999}"/>
      APPSNATIVEMGTPORT=`cat ${APPS_STANDALONE_FILE} | grep "jboss\.management\.native\.port:" | awk -F":" '{print $2}' | awk -F"}" '{print $1}'`
    fi
  fi
fi

if [ -f ${DPdat} ]; then
  if [ x${PGPORT} = x"" ]; then
    PGPORT=`cat ${DPdat} |grep PGPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PGCPPORT} = x"" ]; then
    PGCPPORT=`cat ${DPdat} |grep PGCPPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PGOSUSER} = x"" ]; then
    PGOSUSER=`cat ${DPdat} |grep PGOSUSER | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${APPSSPORT} = x"" ]; then
    APPSSPORT=`cat ${DPdat} |grep APPSSPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${APPSNATIVEMGTPORT} = x"" ]; then
    APPSNATIVEMGTPORT=`cat ${DPdat} |grep APPSNATIVEMGTPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${NOENCRYPTION} = x"" ]; then
    NOENCRYPTION=`cat ${DPdat} |grep NOENCRYPTION | $AWK -F"=" '{ print $2 }'`
  fi
fi

if [ -f ${ParamFile} ]; then
  if [ x${PGPORT} = x"" ]; then
    PGPORT=`cat ${ParamFile} |grep PGPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PGCPPORT} = x"" ]; then
    PGCPPORT=`cat ${ParamFile} |grep PGCPPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${PGOSUSER} = x"" ]; then
    PGOSUSER=`cat ${ParamFile} |grep PGOSUSER | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${APPSSPORT} = x"" ]; then
    APPSSPORT=`cat ${ParamFile} |grep APPSSPORT | $AWK -F"=" '{ print $2 }'`
  fi
  if [ x${APPSNATIVEMGTPORT} = x"" ]; then
    APPSNATIVEMGTPORT=`cat ${ParamFile} |grep APPSNATIVEMGTPORT | $AWK -F"=" '{ print $2 }'`
  fi
fi

if [ x${PGPORT} = x"" ]; then
    PGPORT=7112
fi
if [ x${PGCPPORT} = x"" ]; then
    PGCPPORT=7113
fi
if [ x${PGOSUSER} = x"" ]; then
    PGOSUSER=hpdp
fi
if [ x${APPSSPORT} = x"" ]; then
    APPSSPORT=7116
fi
if [ x${APPSNATIVEMGTPORT} = x"" ]; then
    APPSNATIVEMGTPORT=9999
fi

checkCM=0
checkCM_optional=0
checkCMmem=0

echo "  Validating System requirements..."
echo "  "
CheckRSServer
CheckOSuser ${PGOSUSER}
CheckCMPort ${PGPORT} hpdp-idb
CheckCMPort ${PGCPPORT} hpdp-idb-cp
CheckCMPort ${APPSSPORT} hpdp-as
CheckCMPort ${APPSNATIVEMGTPORT} hpdp-as
CheckKernel
CheckDiskSpace
CheckCMSystemReq

if [ "$NoPreReqCheck" != "Yes" ]; then
  PreRequisiteCheck
fi

echo

if [ "${checkCM}" -eq 1 ]; then
  echo "  Some of the pre-requisites are not satisfied, exiting the installation."
  exit 1
elif [ "${checkCMmem}" -eq 1 ]; then
  echo "  Available system memory is less than required memory. If you wish to continue the installation, please increase the memory to 16GB."
  echo "  "
  exit 1
else
  if [ "${checkCM_optional}" -eq 1 ]; then
    printf "  Some of the system requirements are not satisified, press any key to continue installation or E to exit:"
    while read Answer
    do
      case $Answer in
      E|e)
        echo "  Exiting the installation."
        exit 1
        ;;
      * )
        break
        ;;
      esac
    done
  fi
fi

echo PGPORT=${PGPORT} > $OMNITMP/dpdat
echo PGCPPORT=${PGCPPORT} >> $OMNITMP/dpdat
echo PGOSUSER=${PGOSUSER} >> $OMNITMP/dpdat
echo APPSSPORT=${APPSSPORT} >> $OMNITMP/dpdat
echo APPSNATIVEMGTPORT=${APPSNATIVEMGTPORT} >> $OMNITMP/dpdat

if [ x${NOENCRYPTION} != x"" ]; then
  echo NOENCRYPTION=${NOENCRYPTION} >> $OMNITMP/dpdat
fi  
}

CheckDiskSpace()
{ $Debug

ReqOptOmni=0
ReqEtcOptOmni=0
ReqVarOptOmni=0

if [ x$AddOptCM = x"Yes" ]; then
  ReqOptOmni=`echo "$ReqOptOmni + 1300 * 1024" | bc`
  ReqEtcOptOmni=`echo "$ReqEtcOptOmni + 5 * 1024" | bc`
  ReqVarOptOmni=`echo "$ReqVarOptOmni + 300 * 1024" | bc`
  if [ x$ExportIDB = x"Yes" ]; then
    ReqVarOptOmni=`echo "$ReqVarOptOmni + 1024 * 1024" | bc`
  fi
fi

if [ x$AddOptIS = x"Yes" ]; then
  ReqOptOmni=`echo "$ReqOptOmni + 1400 * 1024" | bc`
  ReqEtcOptOmni=`echo "$ReqEtcOptOmni + 1 * 1024" | bc`
  ReqVarOptOmni=`echo "$ReqVarOptOmni + 1 * 1024" | bc`
fi

if [ ! -d /opt/omni ]; then
  mkdir -p /opt/omni
  chmod 755 /opt/omni
  chown 0:3 /opt/omni
fi
if [ ! -d /etc/opt/omni ]; then
  mkdir -p /etc/opt/omni
  chmod 755 /etc/opt/omni
  chown 0:3 /etc/opt/omni
fi
if [ ! -d /var/opt/omni ]; then
  mkdir -p /var/opt/omni
  chmod 755 /var/opt/omni
  chown 0:3 /var/opt/omni
fi
 MntOptOmni=`df -kP /opt/omni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$6} END {print s}'`
 MntEtcOptOmni=`df -kP /etc/opt/omni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$6} END {print s}'`
 MntVarOptOmni=`df -kP /var/opt/omni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$6} END {print s}'`

if [ $MntOptOmni = $MntEtcOptOmni ]; then
  ReqOptOmni=`echo "$ReqOptOmni + $ReqEtcOptOmni" | bc`
  ReqEtcOptOmni=0
fi
if [ $MntOptOmni = $MntVarOptOmni ]; then
  ReqOptOmni=`echo "$ReqOptOmni + $ReqVarOptOmni" | bc`
  ReqVarOptOmni=0
fi
if [ $MntEtcOptOmni = $MntVarOptOmni ]; then
  ReqEtcOptOmni=`echo "$ReqEtcOptOmni + $ReqVarOptOmni" | bc`
  ReqVarOptOmni=0
fi
if [ $ReqOptOmni != "0" ]; then
  ReqOptOmniGB=`echo "scale=2; ${ReqOptOmni}/(1024*1024)" | bc`
  AvailableSpace=`df -kP $MntOptOmni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$4} END {print s}'`
  AvailableSpaceGB=`echo "scale=2; ${AvailableSpace}/(1024*1024)" | bc`
  result=`echo "if($AvailableSpace>=$ReqOptOmni) 0" | bc`
  if [ x"$result" != x"0" ]; then
    echo "  Error:    Insufficient storage space on the filesystem \"$MntOptOmni\"."  
    echo "            Requires $ReqOptOmni kilobytes ($ReqOptOmniGB GB) of free"  
    echo "            space on the \"$MntOptOmni\" filesystem."  
    echo "            The filesystem \"$MntOptOmni\" has $AvailableSpace ($AvailableSpaceGB GB) kilobytes of free space."  
    checkCM=1
  else
    echo "  Passed:   Requires $ReqOptOmni kilobytes ($ReqOptOmniGB GB) of free"  
    echo "            storage space on the \"$MntOptOmni\" filesystem."
    echo "            The filesystem \"$MntOptOmni\" has $AvailableSpace kilobytes ($AvailableSpaceGB GB) of free space."
  fi
fi
if [ $ReqVarOptOmni != "0" ]; then
  AvailableSpace=`df -kP $MntVarOptOmni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$4} END {print s}'`
  AvailableSpaceGB=`echo "scale=2; ${AvailableSpace}/(1024*1024)" | bc`
  result=`echo "if($AvailableSpace>=$ReqVarOptOmni) 0" | bc`
  if [ x"$result" != x"0" ]; then
    echo "  Error:    Insufficient storage space on the filesystem \"$MntVarOptOmni\"."  
    echo "            Requires $ReqVarOptOmni kilobytes of free"  
    echo "            space on the \"$MntVarOptOmni\" filesystem."  
    echo "            The filesystem \"$MntVarOptOmni\" has $AvailableSpace kilobytes ($AvailableSpaceGB GB) of free space."  
    checkCM=1
  else
    echo "  Passed:   Requires $ReqVarOptOmni kilobytes of free"  
    echo "            storage space on the \"$MntVarOptOmni\" filesystem."  
    echo "            The filesystem \"$MntVarOptOmni\" has $AvailableSpace kilobytes ($AvailableSpaceGB GB) of free space."  
  fi
fi
if [ $ReqEtcOptOmni != "0" ]; then
  AvailableSpace=`df -kP $MntEtcOptOmni | grep -v /net/ | $AWK 'BEGIN{s=0} {s=$4} END {print s}'`
  AvailableSpaceGB=`echo "scale=2; ${AvailableSpace}/(1024*1024)" | bc`
  result=`echo "if($AvailableSpace>=$ReqEtcOptOmni) 0" | bc`
  if [ x"$result" != x"0" ]; then
    echo "  Error:    Insufficient storage space on the filesystem \"$MntEtcOptOmni\"."
    echo "            Requires $ReqEtcOptOmni kilobytes of free"  
    echo "            space on the \"$MntEtcOptOmni\" filesystem."  
    echo "            The filesystem \"$MntEtcOptOmni\" has $AvailableSpace kilobytes ($AvailableSpaceGB GB) of free space."  
    checkCM=1
  else
    echo "  Passed:   Requires $ReqEtcOptOmni kilobytes of free"  
    echo "            storage space on the \"$MntEtcOptOmni\" filesystem."  
    echo "            The filesystem \"$MntEtcOptOmni\" has $AvailableSpace kilobytes ($AvailableSpaceGB GB) of free space."  
  fi
fi

}

CheckKernel()
{ $Debug

case "$SERIES" in 
    gpl/x86_64/linux-x86-64)
        required_shmmax=`echo "2560*1024*1024" | bc`
        required_sysmem=`echo "(15)*1024*1024*1024" | bc`
        req_mem="16 GB"
        req_shmmax="2.5 GB"
        recom_mem="16 GB"
        SHMMAX=`cat /proc/sys/kernel/shmmax`
	#phmem=`cat /proc/meminfo |grep MemTotal: | $AWK '{ print $2 }'`
	#swap=`cat /proc/meminfo |grep SwapTotal: | $AWK '{ print $2 }'`
       #SYSMEM=`echo "${phmem}+${swap}" | bc`
        SYSMEM=`cat /proc/meminfo |grep MemTotal: | $AWK '{ print $2 }'`
        SYSMEM=`echo "${SYSMEM}*1024" | bc`
        SYSMEMGB=`echo "scale=2; ${SYSMEM}/(1024*1024*1024)" | bc`
        SHMMAXGB=`echo "scale=2; ${SHMMAX}/(1024*1024*1024)" | bc`
    ;;
esac

if [ x"$SHMMAX" != x"" ]; then
    result=`echo "if($SHMMAX>=$required_shmmax) 0" | bc`
    if [ x"$result" != x"0" ]; then
        echo "  Error:    Value of the kernel parameter SHMMAX = ${SHMMAX} ($SHMMAXGB GB) is too low."
        echo "            The minimum required parameter value is \"${req_shmmax}\"."
        checkCM=1
    else
        echo "  Passed:   The kernel parameter value: SHMMAX = ${SHMMAX} ($SHMMAXGB GB)."
        echo "            The minimum required parameter value is \"${req_shmmax}\"."
    fi
else
    echo "  Error:    The ${SHORTPRODUCTNAME} setup process cannot obtain value of the kernel parameter SHMMAX."
    echo "            The minimum required parameter value is \"${req_shmmax}\"."
    checkCM=1
fi

if [ x"$SYSMEM" != x"" ]; then
    lowerLimit=`echo "16*1024*1024*1024" | bc`
    case "$SERIES" in 
        gpl/x86_64/linux-x86-64)
            result=`echo "if($SYSMEM>=$required_sysmem) 0" | bc`
            if [ x"$result" != x"0" ]; then
                echo "  Error:    There are \"$SYSMEM\" bytes ($SYSMEMGB GB) of available system memory." 
                echo "            ${req_mem} of system memory is required."
                checkCMmem=1
            else
                if [ "$SYSMEM" -lt "$lowerLimit" ]; then
                  echo "  Passed:   There are \"$SYSMEM\" bytes ($SYSMEMGB GB) (approx. ${req_mem}) of available system memory."
                  echo "            ${req_mem} of system memory is required."
                else
                  echo "  Passed:   There are \"$SYSMEM\" bytes ($SYSMEMGB GB) of available system memory."
                  echo "            ${req_mem} of system memory is required."
                fi
            fi
        ;;
    esac
else
    echo "  Error:    Setup cannot check the amount of the available system memory."
    echo "            ${req_mem} of system memory are required."
    checkCM=1
fi

if [ x$recommended_semmnu != x ]; then
    if [ x$SEMMNU = x ]; then
        echo "  Warning:  Setup cannot obtain value of the kernel parameter SEMMNU."
        echo "            The recommended value is ${recommended_semmnu}."
    elif [ $SEMMNU -lt $recommended_semmnu ]; then
      echo "  Warning:  Value of the kernel parameter SEMMNU = ${SEMMNU} (SEMMNUGB GB) is too low." 
      echo "            The recommended value is ${recommended_semmnu}."
    fi
fi
}

CheckCMPort()
{ $Debug
  SERVICES=/etc/services
  TMP=/tmp/omni_tmp/inst.tmp      
  CMPORT=$1
  CMSERVICE=$2

  L_PORT=`${NETSTAT} -an | grep -w ${CMPORT} | grep LISTEN`    
  OC=`cat "${SERVICES}" | sed -e 's/[	]/ /g' | egrep "^[^#]* +${CMPORT}\/" | $AWK '{print $1}' | uniq`
  if [ "${L_PORT}" ]; then    
    if [ "${OC}" ]; then
      OCC=""
      OCC=`echo "${OC}" | $AWK -v SERV="${CMSERVICE}" '{if($1==SERV) {print $1}}'`
      if [ "${OCC}" != "${CMSERVICE}" ]; then
         echo "  Error:    The ${SHORTPRODUCTNAME} port number \"${CMPORT}\" for the \"${CMSERVICE}\" service is not free."
         checkCM=1
         return 1
      fi
    fi
    if [ "${OC}" -a "${OC}" != "${CMSERVICE}" ]; then 
      $AWK -v POT="^${CMPORT}/" -v SERV="${CMSERVICE}" '{if($1!=SERV && $1!~/^#/ && $2~POT ) { print "#" $0 } else { print $0 }} ' ${SERVICES} > ${TMP} 
      cp ${TMP} ${SERVICES}
      rm ${TMP}
    fi
    echo "  Passed:   Port number \"$CMPORT\" will be used for the \"${CMSERVICE}\" service."
  else
    if [ "${OC}" -a "${OC}" != "${CMSERVICE}" ]; then 
      $AWK -v POT="^${CMPORT}/" -v SERV="${CMSERVICE}" '{if($1!=SERV && $1!~/^#/ && $2~POT ) { print "#" $0 } else { print $0 }} ' ${SERVICES} > ${TMP} 
      cp ${TMP} ${SERVICES}
      rm ${TMP}
    fi
    echo "  Passed:   Port number \"$CMPORT\" will be used for the \"${CMSERVICE}\" service."
  fi
}

# check for reporting server installation
CheckRSServer() {
$Debug
    case "$SERIES" in
        gpl/x86_64/linux-x86-64)
	    if [ "$AddOptCM" = "Yes" -a "$PatchAdd" != "Add" ]; then
            RSrpm=`rpm -qa | grep -i OB2-RS`
            if [ "$RSrpm" != "" ]; then
                echo "  Error :   Found instance of Reporting Server. Cell Manager cannot be installed on Reporting Server."		
	            checkCM=1
            else
                echo "  Passed:   Reporting Server instance not found. Cell Manager can be Installed."		
            fi
        fi
        ;;
    esac
}

CheckOSuser()
{ $Debug
USR=$1
id ${USR} >/dev/null 2>&1
if [ $? != 0 ]; then
  if [ "${USR}" = "${PGOSUSER}" ]; then
    echo "  Error:    The required IDB service user account \"${USR}\" does not exist on the system."
  elif [ "${USR}" = "${RSPGUSER}" ]; then
     echo "  Error:    The user account \"${RSPGUSER}\" does not exist in system."
     echo "            Please create the \"${RSPGUSER}\" user in the system."
  fi
  checkCM=1
  skipOpenFileLimitCheck=1
  return 1
fi
if [ "${USR}" = "${PGOSUSER}" ]; then
  su - ${USR} -c "pwd" >/dev/null 2>&1
  if [ $? != 0 ]; then
    echo "  Error:    The IDB service user account \"${USR}\" is not able to use the logon shell."
    checkCM=1
    return 1
  fi
  echo "  Passed:   The user account \"${USR}\" will be used for the IDB service."
fi
}

CheckPort()
{ $Debug
  SERVICES=/etc/services
  TMP=/tmp/omni_tmp/inst.tmp      
  if [ -f $OMNITMP/socket.dat -a "${INET_PORT}" = "" ]; then
    PORT=`cat $OMNITMP/socket.dat`
  elif [ "${INET_PORT}" != "" ]; then
        if [ -f $OMNITMP/socket.dat ]; then
            printf "        INET port mentioned as a part of command line argument will override socket.dat file\n"
        fi
        while [ 1 ]
        do
        port_len=`echo ${INET_PORT} | tr -d  "[^0-9]"`
        if [ ${#INET_PORT} -eq 0 ]; then
            printf "        Do you want to install with default INET port 5565? [Y/N] :"
            getAnswerEx 
            retAns=$?
            if [ ${retAns} -eq 0 ]; then
                exit 1;
            else
                PORT="5565"
                break;
            fi
        elif [ ${#port_len} -ne 0 ]; then
                printf "        Please enter only numeric characters :"                          
                read INET_PORT                                   
        elif [ ${INET_PORT} -gt 65535 ]; then
                printf "        INET port should be less than 65535 characters :"                                            
                read INET_PORT                                         
        else
            break;
        fi
        done 
    PORT="${INET_PORT}"
    echo ${INET_PORT} > $OMNITMP/socket.dat
  else 
    PORT="5565"  
  fi

  L_PORT=`${NETSTAT} -an | egrep "[^0-9]${PORT} " | grep LISTEN`   
  OC=`cat "${SERVICES}" | sed -e 's/[	]/ /g' | egrep "^[^#]* +${PORT}\/" | $AWK '{print $1}' | uniq`
  if [ "${L_PORT}" ]; then      
    if [ "${OC}" ]; then
      OCC=""
      OCC=`echo "${OC}" | $AWK -v SERV="${SERVICE}" '{if($1==SERV) {print $1}}'`
      if [ "${OCC}" != "${SERVICE}" ]; then
         echo "  Error:    ${SHORTPRODUCTNAME} port number ${PORT} is already occupied."
         echo
         exit 1
      fi
    fi
    if [ "${OC}" -a "${OC}" != "${SERVICE}" ]; then 
      $AWK -v POT="^${PORT}/" -v SERV="${SERVICE}" '{if($1!=SERV && $1!~/^#/ && $2~POT ) { print "#" $0 } else { print $0 }} ' ${SERVICES} > ${TMP} 
      cp ${TMP} ${SERVICES}
      rm ${TMP}
    fi
  else
    if [ "${OC}" -a "${OC}" != "${SERVICE}" ]; then 
      $AWK -v POT="^${PORT}/" -v SERV="${SERVICE}" '{if($1!=SERV && $1!~/^#/ && $2~POT ) { print "#" $0 } else { print $0 }} ' ${SERVICES} > ${TMP} 
      cp ${TMP} ${SERVICES}
      rm ${TMP}
    fi
  fi
}
CheckSystemd()
{ $Debug

    systemd_run=`pidof /usr/lib/systemd/systemd`

    if [ ! "${systemd_run}" ]; then
       if [ ! -f /usr/lib/systemd/systemd -a ! -f /bin/systemd ]; then
          echo "The required systemd daemon is not installed on the client system..."
          exit 1
       else
          if [ ! -f /usr/bin/systemctl ]; then
             echo "The required systemd daemon is not running on the client system..."
             exit 1
          else
             systemd_run=`pidof /usr/lib/systemd/systemd`
             if [ ! "${systemd_run}" ]; then
               echo "The required systemd daemon is not running on the client system..."
               exit 1
             fi
          fi
       fi
    fi
}

CheckXinetd()
{ $Debug
    inetd_run=`ps -ef |grep inetd |grep -v grep`
    if [ ! "${inetd_run}" ]; then
       if [ ! -f /usr/sbin/inetd -a ! -f /usr/sbin/xinetd ]; then
          return 1 # Returns Failure
       elif [ "$CMUpgrade" = "Yes" ]; then
          if [ ! -f /sbin/chkconfig ]; then 
             return 1 # Returns Failure
          else
             inetd_cfg=`/sbin/chkconfig --list |grep xinetd |grep -e 3:on -e 5:on`
             if [ ! "${inetd_cfg}" ]; then
                /sbin/chkconfig xinetd on > /dev/null 2>&1
                inetd_svcs=`/sbin/chkconfig --list | grep [[:space:]]on | $AWK -F: '{ print $1 }' |tr -d [[:space:]]`
                /sbin/chkconfig xinetd off > /dev/null 2>&1
                if [ "${inetd_svcs}" -a "${inetd_svcs}" != "${SERVICE}" ]; then
                   return 1 # Returns Failure
                else
                   /sbin/chkconfig xinetd on > /dev/null 2>&1
                   CC_RET=$?
                   if [ $CC_RET -ne 0 ]; then 
                      return 1 # Returns Failure
                   fi
                fi
             fi
          fi
       fi
    fi

    return 0 # Returns Success
}

CheckForObsoletedLic()
{ $Debug
  OUTPUT=`${OMNIHOME}/bin/omnicc -password_info 2>&1`
  if [ $? -eq 13 ]
  then
    echo "WARNING: Obsoleted licenses detected. Please install new licenses."
  fi
}

ISRemoveEmptyDirs()
{ $Debug
  rmdir ${OMNIHOME}/databases/vendor/informix/hp/s800/hp-ux-113x > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/informix/hp/sia64/hp-ux-113x > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/informix/sun/sparc/solaris-10 > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/informix/sun/sparc/solaris-9 > /dev/null 2>&1

  rmdir ${OMNIHOME}/databases/vendor/sap/gpl/i386/linux-oes > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sap/gpl/x86_64/linux-oes-x86-64 > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sap/hp/s800/hp-ux-113x > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sap/hp/sia64/hp-ux-113x > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sap/sun/sparc/solaris-10 > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sap/sun/sparc/solaris-9 > /dev/null 2>&1
  
  rmdir ${OMNIHOME}/databases/vendor/sybase/hp/s800/hp-ux-113x > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sybase/hp/sia64/hp-ux-113x > /dev/null 2>&1 
  rmdir ${OMNIHOME}/databases/vendor/sybase/sun/sparc/solaris-10 > /dev/null 2>&1
  rmdir ${OMNIHOME}/databases/vendor/sybase/sun/sparc/solaris-9 > /dev/null 2>&1   
}

# Use xinetd if its available, use systemd otherwise
CheckXinetdOrSystemd()
{
      CheckXinetd
      isXinetd=$?

      # Check for Systemd iff Xinetd is not available
      if [ ${isXinetd} = 1 ]; then
          echo "The required xinetd or inetd daemon is NOT installed/running on the client system"
          echo "Checking for systemd..."
          CheckSystemd
      fi

}

ISInstall()
{ $Debug

  echo "Installing ${SHORTPRODUCTNAME} $VERSION Installation Server..."
  echo
  if [ "$AddOptCM" != "Yes" ];then
    if [ "${SEC_DATA_COMM}" != "" ]; then
        echo "Secure Data Communication cannot be enabled during IS installation"
        SEC_DATA_COMM=""
    fi 
    if [ "${AUDITLOG}" != "" ]; then
        echo "Audit logs cannot be enabled during IS installation"
        AUDITLOG=""
    fi
    if [ "${AUDITLOG_RETENTION}" != "" ]; then
        echo "Audit log retention value cannot be modified during IS installation"
        AUDITLOG_RETENTION=""
    fi 	
  fi
  GetTape IS
  if [ "$TAPEFULLPATH" = "" ]; then
    SaveCurrentState
    exit 1
  fi 
  CheckPort
  case "$SERIES" in 
    hp/sia64/hp-ux-113x)
      echo "  The Installation Server component is not available for the $SERIES starting from $PRODUCT 10.50/2019.08"
      exit 1;
    ;;
    gpl/x86_64/linux-x86-64)
      if [ "$CoreInstalled" != "Yes" ]; then
        GPLISComponents="$GPLCoreComponent $GPLISComponents"
        CoreInstalled="Yes"
      fi
      CheckXinetdOrSystemd
      ISRemoveEmptyDirs
      for Packet in $GPLISComponents; do
        echo "Installing $Packet packet"
        rpm -Uvh --replacepkgs --replacefiles $TAPEPATH/$Packet-$VERSION_S-1.x86_64.rpm
        pkgret=$?
        echo
        if [ "$pkgret" != "0" -a "$pkgret" != "2" ]; then
          ErrorHappened=1
          if [ $Packet = "OB2-CORE" ]; then
            echo "  Setup cannot continue. Installation of the ${SHORTPRODUCTNAME} CORE component failed."
            exit 1;
          fi
        fi
      done
      ;;
    *)
      echo "  Installation Server for the platform $SERIES is not supported."
      ;;
  esac

  if [ "$ErrorHappened" != "1" ]; then
    AddOptIS=""
  fi
}

# removes the $* packets from Packets variable
RemoveFromInstallation()
{ $Debug
  NewPackets=""
  for item in $Packets; do

    RemovePacket=No
    for item2 in $*; do
      if [ "$item" = "$item2" ]; then
        RemovePacket=Yes
      fi
    done

    if [ "$RemovePacket" = "No" ]; then
      NewPackets="$NewPackets $item"
    fi
  done
  Packets="$NewPackets"
}

IsDPOBVersionlessThan()
{
    res=0
    if [ x"$DPOBVersion" != x"" ]; then
        compareVer="$1"
        prevVer=`echo $DPOBVersion | sed s/A.// | bc`
		if [ ${prevVer%.*} -eq ${compareVer%.*} ] && [ ${prevVer#*.} \> ${compareVer#*.} ] || [ ${prevVer%.*} -gt ${compareVer%.*} ]; then
		  res=0;
		else
		  res=1;
		fi
    else
        res=1
    fi
    return "$res"
}

CMInstall()
{ $Debug

  GetTape CM
  if [ "$TAPEFULLPATH" = "" ]; then
    exit 1
  fi
  if [ "$1" = "Yes" ]; then
    GetTape IS
    if [ "$TAPEFULLPATH" = "" ]; then
      CheckWork
      SaveCurrentState
      exit 1
    fi 
  fi

  CheckPort
    if [ "${SEC_DATA_COMM}" != "" ]; then
      while [ 1 ]
      do
        len=`echo ${SEC_DATA_COMM} | tr -d  "[^0-9]"`
        if [ ${#SEC_DATA_COMM} -eq 0 ]; then
            printf "        Please enter 1 to enable and 0 to disable option '-secure_data_comm': "
            getAnswerForEnable
            retAns=$?
            if [ ${retAns} -eq 1 -o ${retAns} -eq 0 ]; then
                break;
            else
                printf "        Please enter 1 to enable and 0 to disable option '-secure_data_comm': "
            fi
        elif [ ${#len} -ne 0 ]; then
                echo "        '-secure_data_comm' option has non-numeric characters."
                printf "        Please enter only numeric characters: "
                read SEC_DATA_COMM
        elif [ ${SEC_DATA_COMM} -eq 1 -o ${SEC_DATA_COMM} -eq 0 ]; then
           break;
        else
          printf "        Please enter 1 to enable and 0 to disable option '-secure_data_comm': "
          read SEC_DATA_COMM 
        fi
        done
    fi
    if [ "${AUDITLOG}" != "" ]; then
      while [ 1 ]
      do
        len=`echo ${AUDITLOG} | tr -d  "[^0-9]"`
        if [ ${#AUDITLOG} -eq 0 ]; then
            printf "        Please enter 1 to enable and 0 to disable option '-auditlog': "
            getAnswerForEnable
            retAns=$?
            if [ ${retAns} -eq 1 -o ${retAns} -eq 0 ]; then
                break;
            else
                printf "        Please enter 1 to enable and 0 to disable option '-auditlog': "
            fi
        elif [ ${#len} -ne 0 ]; then
                echo "        '-auditlog' option has non-numeric characters."
                printf "        Please enter only numeric characters: "
                read AUDITLOG
        elif [ ${AUDITLOG} -eq 1 -o ${AUDITLOG} -eq 0 ]; then
           break;
        else
          printf "        Please enter 1 to enable and 0 to disable option '-auditlog': "
           read AUDITLOG 
        fi
      done
      if [ "${AUDITLOG_RETENTION}" != "" ]; then
      while [ 1 ]
      do
        len=`echo ${AUDITLOG_RETENTION} | tr -d  "[^0-9]"`
        if [ ${#AUDITLOG_RETENTION} -eq 0 ]; then
            printf "        Do you want to install with default Audit Log Retention value (90 months)? [Y/N] :"
            getAnswerEx 
            retAns=$?
            if [ ${retAns} -eq 0 ]; then
                exit 1;
            else
                AUDITLOG_RETENTION=90
                break;
            fi
        elif [ ${#len} -ne 0 ]; then
                echo "        '-auditlog_retention' option has non-numeric characters."
                printf "        Please enter only numeric characters :"
                read AUDITLOG_RETENTION
        elif [ "$AUDITLOG_RETENTION" -gt 1188 ] ; then
                printf "        Audit Log Retention value should be less than or equal to 99 years :"
                read AUDITLOG_RETENTION
        else
            break;
        fi
        done
        if [ ${AUDITLOG_RETENTION} -eq 0 ]; then
          printf "  Audit Log Retention value set to 0 will disable Audit log purging."
        fi
      fi
    fi
  if [ "$collectTelemetryData" -ne 0 -a $CMUpgrade = "No" ]; then
       getTelemetryData
  fi

  echo
  if [ "$1" = "Yes" ]; then
    echo "Installing ${SHORTPRODUCTNAME} $VERSION Cell Manager and Installation Server..."
  else
    echo "Installing ${SHORTPRODUCTNAME} $VERSION Cell Manager..."
  fi
  echo

  rm $OMNIHOME/bin/omniamo 2>/dev/null
  rm $OMNIHOME/bin/omnihealthcheck 2>/dev/null

  case "$SERIES" in
    hp/sia64*)
      HPCMComponents="$HPCMComponents1123"
    ;;
  esac

  case "$SERIES" in
    hp/sia64/hp-ux-113x)
      echo "  The Cell Manager component is not available for the $SERIES platform starting from $PRODUCT 10.50/2019.08."
      echo "  Please refer to $PRODUCT documentation for more details"
      exit 1;
    ;;
    gpl/x86_64/linux-x86-64)
      if [ "$1" = "Yes" ]; then
        GPLCMComponents="$GPLCMComponents $GPLISComponents"
        ISRemoveEmptyDirs
      fi
      CheckXinetdOrSystemd
      if [ "$ExistingCellServer" != "" ]; then
          cellServerValue=`cat $OMNICONFIG/client/cell_server 2>/dev/null`
          if [ "$cellServerValue" != "" ]; then
              echo "Current cell_server file entry is $cellServerValue"
              echo "Replacing it with $ExistingCellServer..."
          else
              echo "Creating $OMNICONFIG/client/cell_server with $ExistingCellServer..."
          fi
          echo "$ExistingCellServer" > $OMNICONFIG/client/cell_server
      fi
      for Packet in $GPLCMComponents; do
        echo "Installing $Packet packet"
        if [ "$Packet" = "OB2-DOCS" ]; then
          rpm -Uvh --replacepkgs --replacefiles $TAPEPATH/$Packet-$VERSION_S-1.noarch.rpm 
        else
          rpm -Uvh --replacepkgs --replacefiles $TAPEPATH/$Packet-$VERSION_S-1.x86_64.rpm 
        fi
        pkgret=$?
        echo
        if [ "$pkgret" != "0" -a "$pkgret" != "2" ]; then
          ErrorHappened=1
          if [ $Packet = "OB2-CORE" ]; then
            echo "  Setup cannot continue. Installation of the ${SHORTPRODUCTNAME} CORE component failed."
            exit 1;
          fi
        fi
      done


      CoreInstalled="Yes"
      ;;
    *)
      echo "  Cell Manager for the platform $SERIES is not supported. Exiting..."
      ;;
  esac

  if [ "$ErrorHappened" != 1 ]; then
    if [ "$1" = "Yes" ]; then
      AddOptCM=""
      AddOptIS=""
    else
      AddOptCM=""
    fi

    #if [ -f /tmp/omni_tmp/.omnirc ]; then
    #  cp /tmp/omni_tmp/.omnirc $OMNIHOME
    #  rm /tmp/omni_tmp/.omnirc
    #fi

# so, the Cell Manager has been successfully installed. That means we have also 
# successfully installed core, ma, da, cc, javagui and docs client components
# (Packets variable). Remove them from client installation

    RemoveFromInstallation omnicf ts_core ma da cc docs

    CheckForObsoletedLic
  fi

    if [ "${SEC_DATA_COMM}" != "" ]; then
      if [ ${SEC_DATA_COMM} -eq 1 ]; then
        Output=`${OMNIHOME}/bin/omnicc -secure_data_comm 1 $DebugOpts 2>/dev/stdout`
        if [ $? != 0 ]; then
          echo
          echo "Secure data communication is not enabled."
        fi
      elif [ ${SEC_DATA_COMM} -eq 0 ]; then
        Output=`${OMNIHOME}/bin/omnicc -secure_data_comm 0 $DebugOpts 2>/dev/stdout`
        if [ $? != 0 ]; then
          echo
          echo "Secure data communication is not disabled."
        fi
      fi
    fi
    if [ "${AUDITLOG}" != "" ]; then
      if [ ${AUDITLOG} -eq 1 ]; then
        if [ "${AUDITLOG_RETENTION}" != "" ]; then
          Output=`${OMNIHOME}/bin/omnicc -auditlog 1 -retention_months ${AUDITLOG_RETENTION} $DebugOpts 2>/dev/stdout`
        else
          Output=`${OMNIHOME}/bin/omnicc -auditlog 1 $DebugOpts 2>/dev/stdout`
        fi
        if [ $? != 0 ]; then
          echo
          echo "Audit logs are not enabled."
        fi
      elif [ ${AUDITLOG} -eq 0 ]; then
        Output=`${OMNIHOME}/bin/omnicc -auditlog 0 $DebugOpts 2>/dev/stdout`
        if [ $? != 0 ]; then
          echo
          echo "Audit logs are not disabled."
        fi
      fi
    fi
#Automigration of the keys and backup specs for the CM.
#This will happen only if upgrade happens from DP6.0 to DP6.1

   if [ $AutoMigrate = "Yes" ]; then
    if [ -f ${OMNIHOME}/sbin/omnikeymigrate ] ;then
        MigrateOutput=`${OMNIHOME}/sbin/omnikeymigrate -client \`hostname\` 2>/dev/null`
        grep "failed" MigrateOutput 2>/dev/null 1>&2
        if [ $? -eq 0 ]; then
           echo
           echo "  Migration of encryption key(s) failed."
           echo "  Please run \"omnikeymigrate -client `hostname`\" manually after Installation/upgrade."
        else
           echo
           echo "  Migration of encryption key(s) completed successfully."
        fi
    fi
  fi
  
    if [ "$collectTelemetryData" -ne 0 -a $CMUpgrade = "No" ]; then
     updateTelemetryDataInDB
    fi


   HOST_NAME=`hostname | $AWK -F"." '{ print $1 }' | tr "[A-Z]" "[a-z]"`
   CellSvr_O=`cat $OMNICONFIG/client/cell_server| tr "[A-Z]" "[a-z]"  2>/dev/null`
   CellSvr=`echo $CellSvr_O | $AWK -F"." '{ print $1 }'`

   
    #LDAP Integrated to Keycloak in DP 10.04 version
    #if DP upgrade happens from DP version less than or equal to 10.03,
    #And LDAP is configured in Cell Manager, it needs to migrate to
    #keycloak and LDAP configuration needs to be removed from standalone.xml file.
    #Otherwise(if DP version is greater than 10.03) it needs to be removed from standalone.xml file as loginprover.war
    #file removed from DP appserver
    #Here "1" stands for Migrate LDAP to Keycloak required,
    # "0" stands for Remove LDAP configuration from standalone.xml

   IsDPOBVersionlessThan 10.03
   if [ "$?" = 1 ]; then
     echo "Migrating Ldap Configuration to Keycloak .."
     migrateLDAPToKeycloak=1
     ldapConfigMigrate $migrateLDAPToKeycloak
   else
       #Remove Ldap Configuration from Wildfly configuration file
       #if upgrade happens from < 10.70
       IsDPOBVersionlessThan 10.60
       if [ "$?" = 1 ]; then
           migrateLDAPToKeycloak=0
           ldapConfigMigrate $migrateLDAPToKeycloak
       fi
   fi

   #There is no need to migrate users when the upgrade is from 10.03 or higher versions
   IsDPOBVersionlessThan 10.03
   if [ "$?" = 1 ]; then
     echo "Migrating Users .."
     userMigrate
   fi
  
   IsAppserverRunning=`/opt/omni/sbin/omnisv status 2>/dev/null |grep hpdp-as | $AWK '{print $4}'`

   getNumericVersion
   flag=$?
   
   #No need to run migration schedule for cluster upgrade
   #it will be run as part of cluster script
  if [ x"$IsAppserverRunning" != x"" ]; then
   if [ $flag -eq 1 -o $flag -eq 2 ]; then
       if [ "$CMUpgrade" = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then
           echo
           echo "Schedules not migrated."
           echo "Once cluster services are up, please run \"omnidbutil -migrate_schedules -only_advsch\"."
       else
           if [ -f ${OMNIHOME}/sbin/omnidbutil ] ;then
                logfile=/var/opt/omni/server/log/migration.log
                ${OMNIHOME}/sbin/omnidbutil -migrate_schedules -only_advsch -debug 0-200 migrateschedules.txt | tee $logfile
                SchedMigrateFailed=`grep "failed" $logfile|wc -l`
                SchedMigrateOk=`grep "ok" $logfile|wc -l`
                if [ "$SchedMigrateFailed" -ne 0 -o "$SchedMigrateOk" -eq 0 ]; then
                    echo "" 1>&2
					if [ "$CMUpgrade" = "No" ]; then
						echo "Migration of $SchedMigrateFailed Template(s) failed." 1>&2
					else
						echo "Migration of $SchedMigrateFailed advanced schedule(s) failed." 1>&2
						echo "Check for migrated advanced schedules details on  /var/opt/omni/server/log/migration.log"
						echo "Please run \"omnidbutil -migrate_schedules -only_advsch\" manually after Installation/upgrade." 1>&2
					fi 
               else
                    if [ "$CMUpgrade" = "No" ]; then
						echo "Migration of Template(s) completed successfully."
					else
						echo "Migration of advanced schedule(s)& Template(s) completed successfully."
						echo "Check for migrated advanced schedules details on  /var/opt/omni/server/log/migration.log"
					fi  
               fi
           fi
       fi
   

   elif [ $flag -eq 0 ]; then
       if [ "$CMUpgrade" = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then
           echo
           echo "template.migrate files are not renamed."
           echo "Once cluster services are up, please run \"omnidbutil -reinstate_legacy_schedules -tmpl\"."
       else
           if [ -f ${OMNIHOME}/sbin/omnidbutil ] ;then
                ${OMNIHOME}/sbin/omnidbutil -reinstate_legacy_schedules -tmpl -debug 0-200 migrateschedules.txt
           fi
       fi
   

   elif [  "$CMUpgrade" = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then
       echo
       echo "Schedules not migrated."
       echo "Once cluster services are up, please run \omnidbutil -migrate_schedules -only_advsch\" manually after Installation/upgrade."
    fi
	
    if [ "$ErrorHappened" != 1 ]; then
        AddJavaUser
    fi
	 
    if [ $flag -eq 1 ]; then
      OptimizeSchedules
    fi
  else
     echo "Skipped scheduler migration as services are not up and running"
  fi

  #remove unused files post CM Install/Upgrade
  rm -f /etc/opt/omni/server/AppServer/dataprotector.json 1>&2
  rm -f /var/opt/omni/server/AppServer/keycloak.mv.db 1>&2
  rm -f /var/opt/omni/server/AppServer/keycloak.trace.db 1>&2

  if [  "$CMUpgrade" = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then
     echo
     echo "Cluster detected,Please run "
     echo "/opt/omni/sbin/install/omniforsg.ksh -primary -upgrade "
     echo "or "
     echo "/opt/omni/sbin/install/omniforsg.ksh -secondary -upgrade "
     echo "as applicable for cluster upgrade, please refer cluster \"Upgrade the Cell Manager configured in Serviceguard\" section in documentation for more details."
  fi
}

getNumericVersion()
{
  true=1;
  false=0;
  flag=0;
  version="10.00"
  if [ "$DPOBVersion" != "" ]; then
   numericVersion=`echo $DPOBVersion |cut -c3-10`
   flag=`echo "$numericVersion $version $true $false" | awk '{if ($1 < $2) print $3;else print $4}'`

  else
   flag=2  
  fi
  return "$flag"
	
}

ldapConfigMigrate()
{
    migrateLDAPToKeycloak=$1
    #find if LDAP is configured or not
    #if LDAP is not configured, No need to proceed
    `grep "<login-module code=\"LdapExtended\" flag=\"optional\">" /etc/opt/omni/server/AppServer/standalone.xml > /dev/null`
    if [ $? != 0 ];then
        return
    fi

    errorMsg=""
    ldapOption=""
    if [ $migrateLDAPToKeycloak = 1 ]; then
        ldapOption=configureLdap
        errorMsg="ERROR: LDAP  Migration to Keycloak failed. Please check the latest log file  /var/opt/omni/log/ omniasutil*  for more details."
    else
        ldapOption=removeldapconfig
        errorMsg="ERROR: Removing LDAP  configuration from standalone.xml failed. Please check the latest log file  /var/opt/omni/log/ omniasutil*  for more details."
    fi
    #Checking for the cluster setup
     if [ $CMUpgrade = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then   
        echo
        echo "LDAP configurations are not migrated."
        echo "Once cluster services are up, please run \"/opt/omni/bin/perl /opt/omni/sbin/omniasutil.pl -${ldapOption}\"."
     else
        if [ -f ${OMNIHOME}/sbin/omniasutil.pl ]; then
           logfile=/var/opt/omni/server/log/ldapmigrate.log
           ${OMNIHOME}/bin/perl ${OMNIHOME}/sbin/omniasutil.pl -${ldapOption} 2>/dev/null > $logfile
           rc=`echo $?`
           if [ "$rc" != "0" ]; then
             echo " "
             echo $errorMsg
           fi
        fi
     fi	 
}

AddJavaUser()
{
    #Checking for the cluster setup
     if [ $CMUpgrade = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then   
        echo
        echo "---Add Java user---"
        echo "Once cluster services are up, please run \"/opt/omni/bin/perl /opt/omni/sbin/omniasutil.pl -addjavauser\"."
     else
        if [ -f ${OMNIHOME}/sbin/omniasutil.pl ]; then
           logfile=/var/opt/omni/server/log/addjavauser.log
           ${OMNIHOME}/bin/perl ${OMNIHOME}/sbin/omniasutil.pl -addjavauser 2>/dev/null > $logfile 
           rc=`echo $?`
           if [ "$rc" != "0" ]; then
             echo " "
             echo "ERROR: java user addition failed. Please check the latest log file  /var/opt/omni/log/ omniasutil*  for more details."

           fi
        fi
     fi	 
}

userMigrate()
{
    #Checking for the cluster setup
     if [ $CMUpgrade = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then   
        echo
        echo "Users are not migrated."
        echo "Once cluster services are up, please run \"/opt/omni/bin/perl /opt/omni/sbin/userMigrate.pl\"."
     else
        IsAppserverRunning=`/opt/omni/sbin/omnisv status 2>/dev/null |grep hpdp-as | $AWK '{print $4}'`
        if [ x"$IsAppserverRunning" = x"" ]; then
            echo "Skipped user migration as Appserver is not up and running"
            return 1
        fi

        if [ -f ${OMNIHOME}/sbin/userMigrate.pl ]; then
           ${OMNIHOME}/bin/perl ${OMNIHOME}/sbin/userMigrate.pl
           rc=`echo $?`
           if [ "$rc" != "0" ]; then
             echo " "
             echo "ERROR: User Migration failed. Please check the log file  /var/opt/omni/server/log/dp_user_migrate.log  for more details."
           else
             echo "User Migration completed successfully."	
           fi
        fi	
     fi	 
}

AddRoles()
{
    #For Upgrade, add new role. Skip for fresh installation, as userMigrate will add all the roles.
    if [ $CMUpgrade = "Yes" ]; then
        #Checking for the cluster setup
        if [ "$CellSvr" != "$HOST_NAME" ]; then
            echo
            echo "Users and admin group roles are not added."
            echo "Once cluster services are up, please run \"/opt/omni/bin/omniusers -addroles\"."
            echo "Once cluster services are up, please run \"/opt/omni/bin/omniusers -update_admin_group\"."
        else
            IsAppserverRunning=`/opt/omni/sbin/omnisv status 2>/dev/null |grep hpdp-as | $AWK '{print +$4}'`
            if [ x"$IsAppserverRunning" = x"" ]; then
                echo "Skipped adding user roles as Appserver is not up and running"
                return 1
            fi

            if [ -f ${OMNIHOME}/bin/omniusers ]; then
                ${OMNIHOME}/bin/omniusers -addroles -debug 1-300 add_roles.txt > /dev/null 2>&1
                rc=`echo $?`
                if [ "$rc" != "0" ]; then
                    echo " "
                    echo "ERROR: AddRoles failed. Skipped to update admin group roles"
                else
                    echo "AddRoles completed successfully."
                    ${OMNIHOME}/bin/omniusers -update_admin_group -debug 1-300 update_group.txt > /dev/null 2>&1
                    rc=`echo $?`
                    if [ "$rc" != "0" ]; then
                        echo " "
                        echo "ERROR: Admin group roles update failed."
                    else
                        echo "Admin group roles updated successfully."
                    fi
                fi
            fi
        fi
    fi
}

OptimizeSchedules()
{
   #No need to run schedule optimization for cluster upgrade
   #it will be run as part of cluster script
   if [ $CMUpgrade = "Yes" -a  "$CellSvr" != "$HOST_NAME" ]; then   
      echo
      echo "Schedules are not optimized."
      echo "Once cluster services are up, please run \"omnidbutil -optimize_schedules\"."
   else
       if [ -f ${OMNIHOME}/sbin/omnidbutil ] ;then
       logfile=/var/opt/omni/server/log/optimize.log
       ${OMNIHOME}/sbin/omnidbutil -optimize_schedules -debug 0-200 optimizeschedules.txt  | tee $logfile
       SchedOptimizeFailed=`grep "success" $logfile|wc -l`
               
           if [ "$SchedOptimizeFailed" -ne 0 ]; then
                echo   
                echo "Optimization of schedule(s) completed successfully."
           else                               
                echo
                echo "Optimization of schedule(s) failed."
                echo "Please run \"omnidbutil -optimize_schedules\" manually after Installation/upgrade."
           fi
        fi
    fi	
}

ClientInstall()
{ $Debug
  if [ "$Packets" = "" ]; then
    echo "  No Packets selected, exiting..."
    exit 2
  fi
  if [ "${SEC_DATA_COMM}" != "" ]; then
        echo "  Secure Data Communication cannot be enabled during client installation"
        SEC_DATA_COMM=""
  fi 
  if [ "${AUDITLOG}" != "" ]; then
        echo "  Audit logs cannot be enabled during client installation"
        AUDITLOG=""
  fi
  if [ "${AUDITLOG_RETENTION}" != "" ]; then
        echo "Audit log retention value cannot be modified during client installation"
        AUDITLOG_RETENTION=""
  fi  
  echo
  echo
  echo "  Packets going to be (re)installed: $Packets"
  echo

  CellServer_S=`echo $CellServer | $AWK -F"." '{ print $1 }'`
  HOSTNAME_S=`hostname` | $AWK -F"." '{ print $1 }'  
  
# Report a Message when upgrading the client using omnisetup.

  if [ "$CellServer_S" = "$HOSTNAME_S" -a "$AutoMigrate" = "Yes" ]; then
    AutoMigrate="No"
  fi

  PerformInstallation

  if [ "$ErrorHappened" != "1" -a "$AutoMigrate" = "Yes" ]; then
        echo
        echo "  To migrate the encryption keys and enable encryption in all" 
        echo "  backup specification(s) associated with this client," 
        echo "  Please run \"omnikeymigrate -client `hostname`\" in the cell manager $CellServer"
        echo
  fi

  ImportClient

  if [ "$ErrorHappened" != 1 ]; then
    Packets=""
  fi
}

ExtractPacket()
{ $Debug

  if [ "$targetfolder" != "" ]; then
	if [ ! -d $targetfolder ]; then
	  mkdir -p $targetfolder
	fi
	packetfolder=$targetfolder
	packets=$targetfolder
  else
    mkdir -p $SrcDir/packets
    packets=$SrcDir/packets
	packetfolder=$packets
  fi
  mkdir -p $packets/utils/$SERIES
  packetu=$packets/utils/$SERIES
  if [ "$package" = "MR" ]; then
    CheckWork
	if [ "$SERIES" = "sun/sparc/solaris-8" ]; then
	  SERIES=sun/sparc/solaris-10
	  solaris8=y
	fi
	UnpackSelected $SDLabel
	if [ "$solaris8" = "y" ]; then
	  SERIES=sun/sparc/solaris-8
	fi
	for Packet in $Packets
	do
	  mkdir -p $packetfolder/$Packet/$SERIES/$VERSION/
	  packets=$packetfolder/$Packet/$SERIES/$VERSION/
	  GetDirectory $Packet $SDLabel
	  FullPacketName $Packet
	  echo "Copying $PushPacketFullName packet..."	  
	  if [ "$SWPackage" = "Yes" ]; then
        if [ -f $SrcDir/$PacketFullPath ]; then
          cp $SrcDir/$PacketFullPath $packets
        else
          echo "Could not extract $Packet component from bundle/patch"
		  if [ -z "$(ls -A $packetfolder/$Packet)" ]; then
		    rm -rf $packetfolder/$Packet
          fi  
        fi  
      else
        if [ -f $TAPEPATH/$PacketFullPath ]; then
          cp $TAPEPATH/$PacketFullPath $packets
        elif [ -f $PacketFullPath ]; then
          cp $PacketFullPath $packets
        else
          echo "Could not extract $Packet component from bundle/patch"
		  if [ -z "$(ls -A $packetfolder/$Packet)" ]; then
		    rm -rf $packetfolder/$Packet
          fi  
        fi
      fi
	  rm -rf opt/
	done
    cd ..
  elif [ "$package" = "MMR" -o "$package" = "patchhpux" ]; then
    GetTapeComp
    if [ "$TAPEFULLPATH" = "" ]; then
      echo "  Setup cannot continue. Please, insert the installation media with HP-UX Installation"
      echo "  Server and run the installation script again without options. Setup will then be able to proceed."
      echo 
      TapeMissing="Yes"
    fi
	if [ "$TapeMissing" = "Yes" ]; then
    exit 1
	fi
	if [ "$SERIES" = "sun/sparc/solaris-8" ]; then
	  SERIES=sun/sparc/solaris-10
	  solaris8="y"
	fi
	UnpackSelectedComp $SDLabel
	if [ "$solaris8" = "y" ]; then
	  SERIES=sun/sparc/solaris-8
	fi
	cd $SrcDir
	for Packet in $Packets
	do
	  mkdir -p $packetfolder/$Packet/$SERIES/$VERSION/
	  packets=$packetfolder/$Packet/$SERIES/$VERSION/
	  GetDirectoryComp $Packet $SDLabel
	  FullPacketName $Packet
	  echo "Copying $PushPacketFullName packet..."
        if [ -f $TAPEPATH/$PacketFullPath ]; then 
          cp $TAPEPATH/$PacketFullPath $packets
        elif [ -f $PacketFullPath ]; then 
          cp $PacketFullPath $packets
        else
          echo "Could not extract $Packet component from bundle/patch"
		  if [ -z "$(ls -A $packetfolder/$Packet)" ]; then
		    rm -rf $packetfolder/$Packet
          fi
        fi
        rm -rf opt/
	      if [ -f $SrcDir/$hpuxfil ]; then
		    cd $packets
		    `gunzip packet.Z`
		    `mv packet packet.Z`
		    cd $SrcDir
		  fi
	  removeFolder=`echo $PacketFullPath | $AWK -F'[/]' '{print $1}'`
      rm -rf ${removeFolder}
	done
  fi
  
    echo    "Packets are extracted under $packetfolder folder. Follow the below procedure to install the components in clients:"
    echo    	"1. Create a new folder in client and copy $packetfolder/utils/<SERIES>/utils.tar and untar it (tar -xvf <utils.tar> ) to get omni_rinst.sh script"
    echo    	"2. copy  packet.Z ($packetfolder/<component name>/<SERIES>/<VERSION>/packet.Z)of each component to client in new folder"
    echo    	"3. execute the following command for each of the component"
    echo        "./omni_rinst.sh <PacketPath> <PacketToInstall> <VERSION> <SERIES> /opt/omni/ null <InetPort>"
    echo        "PacketPath = Path of packet.Z"
    echo        "PacketToInstall = Name of packet (Ex: omnicf = core, ts_core = ts_core, da = da)"
    echo        "VERSION = A.10.00"
    echo    	"SERIES = client platform ex: gpl/x86_64/linux-x86-64"
    echo        "InetPort = Inet Port number, ex: 5565"
    echo    	"Command should be executed for each component with their specific packet.Z files"
	echo	
    echo    	"Following command is an example to install da component"
    echo        "./omni_rinst.sh /tmp/omni_tmp/packet.Z da A.10.00 gpl/x86_64/linux-x86-64 /opt/omni null 5565"
	echo		"                                     "
	echo	"Core component (omnicf and ts_core) should be installed first before installing any other component"

}

BrandingCopyAndExtractPkg()
{
  $Debug
  SRCDIR=$1
  TGTDIR=$2

  cp ${SRCDIR}/${BRANDING_PKGNAME} ${TGTDIR}/${BRANDING_PKGNAME}
  if [ $? -ne 0 ]; then
    return 1
  fi

  MY_OLDPWD=`pwd`
  cd ${TGTDIR}
  tar xvf ${BRANDING_PKGNAME} >/dev/null 2>/dev/null
  RETV=$?
  cd ${MY_OLDPWD}

  if [ ${RETV} -ne 0 ]; then
    return 1
  fi

  return 0
}

BrandingInit()
{
  $Debug
  BRANDING_DIRNAME="branding"
  BRANDING_CFGNAME="branding.ini"
  BRANDING_PKGNAME="branding.tar"
  PRODBRANDINGDIR=${OMNIHOME}/${BRANDING_DIRNAME}

  if [ ! -f ${SrcDir}/${BRANDING_PKGNAME} ]; then
    return 0
  fi
  
  mkdir ${PRODBRANDINGDIR} 2>/dev/null
  if [ -e ${PRODBRANDINGDIR} ]; then
    BrandingCopyAndExtractPkg ${SrcDir} ${PRODBRANDINGDIR}
    if [ $? -eq 0 ]; then    
      return 0
    fi
  fi

  BrandingCopyAndExtractPkg ${SrcDir} ${OMNITMP}
  if [ $? -eq 0 ]; then
    return 0
  fi
  
  echo "ERROR: Product branding initialization failed."
  exit 2
}

BrandingInitVariables()
{
  $Debug
  BRANDING_DIRNAME="branding"
  BRANDING_CFGNAME="branding.ini"
  BRANDING_PKGNAME="branding.tar"
  PRODBRANDINGCURRENTDIR=${OMNIHOME}/${BRANDING_DIRNAME}
  
  if [ ! -d ${PRODBRANDINGCURRENTDIR} ]; then
    if [ -d ${OMNITMP} ]; then
      PRODBRANDINGCURRENTDIR=${OMNITMP}
    fi
  fi
  
  if [ -f "${PRODBRANDINGCURRENTDIR}/$BRANDING_CFGNAME" ]; then
    BRIEFPRODUCTNAME=`cat $PRODBRANDINGCURRENTDIR/$BRANDING_CFGNAME 2>&1|grep BRIEF_PRODUCT_NAME= | $AWK -F"=" '{ print $2 }'`
    BRIEFPRODUCTNAME2=`cat $PRODBRANDINGCURRENTDIR/$BRANDING_CFGNAME 2>&1|grep BRIEF_PRODUCT_NAME2= | $AWK -F"=" '{ print $2 }'`
    SHORTPRODUCTNAME=`cat $PRODBRANDINGCURRENTDIR/$BRANDING_CFGNAME 2>&1|grep SHORT_PRODUCT_NAME= | $AWK -F"=" '{ print $2 }'`
    FULLPRODUCTNAME=`cat $PRODBRANDINGCURRENTDIR/$BRANDING_CFGNAME 2>&1|grep FULL_PRODUCT_NAME= | $AWK -F"=" '{ print $2 }'`

    if [ "$BRIEFPRODUCTNAME" = "" ]; then
      BRIEFPRODUCTNAME="Data Protector"
    fi
    if [ "$BRIEFPRODUCTNAME2" = "" ]; then
      BRIEFPRODUCTNAME2="Data Protector"
    fi
    if [ "$SHORTPRODUCTNAME" = "" ]; then
      SHORTPRODUCTNAME="Data Protector"
    fi
    if [ "$FULLPRODUCTNAME" = "" ]; then
      FULLPRODUCTNAME="Micro Focus Data Protector"
    fi
  else
      BRIEFPRODUCTNAME="Data Protector"
      BRIEFPRODUCTNAME2="Data Protector"
      SHORTPRODUCTNAME="Data Protector"
      FULLPRODUCTNAME="Micro Focus Data Protector"
  fi
  InstalledProductName="${SHORTPRODUCTNAME}"
}

checkSymLinks() {
  
  case "${SERIES}" in
    gpl/*/linux*|*s390x*)

      if [ -L "$OMNIHOME" ] && [ -d "$OMNIHOME" ]
      then
        link="true"
        linkOptOmni=`readlink -f $OMNIHOME`
      fi

      if [ -L "$OMNIDATA" ] && [ -d "$OMNIDATA" ]
      then
        link="true"
        linkVarOmni=`readlink -f $OMNIDATA`
      fi

      if [ -L "$OMNICONFIG" ] && [ -d "$OMNICONFIG" ]
      then
        link="true"
        linkEtcOmni=`readlink -f $OMNICONFIG`
      fi

    ;;
  esac
}

reSymLink() {
  case "${SERIES}" in
    gpl/*/linux*|*s390x*)

      if [ ! -L "$OMNIHOME" ]; then
        if [ "$linkOptOmni" != "" -a -d "$linkOptOmni" ]; then
          `rm -rf $OMNIHOME`
          `ln -s $linkOptOmni $OMNIHOME`
        fi
      fi
 
    if [ ! -L "$OMNIDATA" ]; then
      if [ "$linkVarOmni" != "" -a -d "$linkVarOmni" ]; then
        `ln -s $linkVarOmni $OMNIDATA`
      fi
    fi  
  
    if [ ! -L "$OMNICONFIG" ]; then
      if [ "$linkEtcOmni" != "" -a -d "$linkEtcOmni" ]; then
        `rm -rf $OMNICONFIG`
        `ln -s $linkEtcOmni $OMNICONFIG`
      fi
    fi
  ;;
  esac
}

VerifyAppServerCert()
{
    ret=0
    UNAME=`uname -s`

    IsDPOBVersionlessThan 10.70
    if [ "$?" = 1 ]; then
        password=`cat /etc/opt/omni/client/components/webservice.properties | grep truststorePassword | grep -v '^\s*#' | $AWK -F"=" '{ print $2 }'`
    else
        password=`/opt/omni/bin/perl /opt/omni/sbin/omniasutil.pl -parsetruststorepasswd `
    fi
    exception=`/opt/omni/jre/bin/keytool -list -keystore /etc/opt/omni/server/certificates/server/server.truststore -storepass $password 2>&1|grep "Exception"|wc -l`
    temp=`/opt/omni/jre/bin/keytool -list -keystore /etc/opt/omni/server/certificates/server/server.truststore -storepass $password 2>&1|grep cn=ca`
    host=`echo $temp | $AWK -F" " '{ print $2 }' | $AWK -F"," '{ print $1 }'`
    org=`echo $temp | $AWK -F"," '{ print $2 }' | $AWK -F"=" '{ print $2 }'`
    SystemName=`cat $OMNICONFIG/client/cell_server`
    if [ $exception -gt 0 ]; then
      echo "  Warning:  Application Server Keystore is corrupted. If custom certificates are used, do reimport the certificates after installation."
      echo "            Installation will be continued with new certificates."
      export REGENCERT=1
      echo "1" > /tmp/regencert
      hasWarn=1
      ret=1
    elif [ "$host" != "$SystemName" ]; then
      export REGENCERT=1
      echo "1" > /tmp/regencert
      if `echo "$org" | grep -q "hewlett packard"` || `echo "$org" | grep -q "hewlett-packard"` || `echo "$org" | grep -q "micro focus"`; then
        echo "  Warning:  Hostname in Application Server certificate ${host} does not match with current hostname ${SystemName}. "
        echo "            Application Server certificate's will be regenerated. "
      else 
        echo "  Warning:  Custom certificates in application server are corrupted. Do reimport the certificates after installation."
        echo "            Installation will be continued with new certificates."
      fi
      hasWarn=1
      ret=1
    # hostname matches but it’s upgrade from pre 10.03 version. So regenerate the certificate’s only in case of DP generated certificates
    elif `echo "$org" | grep -q "hewlett packard"` || `echo "$org" | grep -q "hewlett-packard"`; then
      export REGENCERT=1
      echo "1" > /tmp/regencert
    #As subject alternate name is added for the certs in 10.10, upgrade to this version should regenerate certs
    elif [ x"$DPOBVersion" != x"" ]; then
      ver1010="10.10"
      prevVer=`echo $DPOBVersion | sed s/A.// | bc`
	  res=`echo "$prevVer < $ver1010" | bc`
      if [ "$res" -eq 1 ]; then
        if `echo "$org" | grep -q "micro focus"`; then
            export REGENCERT=1
            echo "1" > /tmp/regencert
        fi
      fi
    else
        echo "  Passed:   Application Server keystore verified successfully. " 
    fi
    return $ret
}

CellNameCheck()
{
  HOST_NAME=`hostname`
  FULLHOSTNAME=`/opt/omni/lbin/utilns/hostlookup $HOST_NAME 2>/dev/null | tr '[A-Z]' '[a-z]'`
  CMname=`/opt/omni/sbin/omnidbutil -show_cell_name 2>/dev/null | $AWK -F':' '{print $2}' | cut -d '"' -f2`
  if [ "$CMname" = "" ]; then
    read -r CMname<${OMNICONFIG}/client/cell_server
  fi
  if [ "$CMname" = "" ]; then
    echo "  Error:    Cell Server name could not be retrieved."
    hasErr=1
    return 1
  fi
  # check CMname with hostnames if hostnames are changed
  if test "$FULLHOSTNAME" != "" -a "$FULLHOSTNAME" != "${FULLHOSTNAME#$CMname}"; then
    echo "  Passed:   Hostname matches with Cell Server name."
    return 0
  elif test "$HOST_NAME" != "" -a "$HOST_NAME" != "${HOST_NAME#$CMname}"; then
    echo "  Passed:   Hostname matches with Cell Server name."
    return 0
  else
    # We check sg.conf file to determine cluster environment and there is a chance that sg.conf is tampered in standalone case as well.
    # Read CS_SERVICE_HOSTNAME from sg.conf file for cluster environment
    sgconfHostname=`cat /etc/opt/omni/server/sg/sg.conf 2>/dev/null |  grep -v "#CS_SERVICE_HOSTNAME" | grep "CS_SERVICE_HOSTNAME" | cut -d"=" -f2 | cut -d '"' -f2`
    if [ "$sgconfHostname" = "" ]; then
        echo "  Error:    SG Cluster Host  name could not be retrieved."
        hasErr=1
        return 1
    else
        if [ $CMname = $sgconfHostname ]; then
          echo "  Passed:   Hostname matches with Cell Server name."
          return 0
        else
          echo "  Error:    Hostname does not match with Cell Server name."
          hasErr=1
          return 1
        fi
    fi
  fi
}
StartMaintenanceMode()
{
  if [ $CMUpgrade = "Yes" -o -f /etc${OMNIHOME}/server/idb/version.txt ]; then
    latestVersion=`echo $VERSION | awk -F"." '{ print $2 $3 }'`
    if [ $Old_Version -lt $latestVersion ]; then
      if [ $Old_Version -lt 1000 ]; then
        maintenanceFile=/var${OMNIHOME}/server/db80/maintenance.tmp
      else
        maintenanceFile=/etc${OMNIHOME}/server/AppServer/maintenance
      fi
      if [ ! -f $maintenanceFile ]; then
        touch $maintenanceFile 
        SustainMaintenanceMode=0
        echo "  ${SHORTPRODUCTNAME} is put in Maintenance Mode." 
      fi
    fi
  fi
}
StopMaintenanceMode()
{
  if [ "$SustainMaintenanceMode" -eq 0 ]; then
    if [ -f /etc${OMNIHOME}/server/cell/mmdb_server ]; then
      stop_maintenance=`${OMNIHOME}/sbin/omnisv -maintenance -stop -cmmdb_force 2>/dev/null`
      if [ "$?" -ne 0 ]; then
        echo "Error:    Stopping maintenance mode"
        return 1
      fi
    elif [ -f /etc${OMNIHOME}/server/cell/mom_info ]; then
      stop_maintenance=`${OMNIHOME}/sbin/omnisv -maintenance 10 -mom_stop 2>/dev/null`
      if [ "$?" -ne 0 ]; then
        echo "Error:    Stopping maintenance mode"
        return 1
      fi
    else 
      stop_maintenance=`${OMNIHOME}/sbin/omnisv -maintenance -stop 2>/dev/null`
      if [ "$?" -ne 0 ]; then
        echo "Error:    Stopping maintenance mode"
        return 1
      fi
    fi
    echo "Maintenance Mode has been removed."
  fi
}
ASConsistencyCheck()
{
  cmd="$(${OMNIHOME}/AppServer/bin/jboss-cli.sh -c --command="/subsystem=datasources/data-source=IDBPostgreSQLDS_Pool:test-connection-in-pool" 2>/dev/null |grep outcome |awk -F">" '{ print $2}'|  awk -F" " '{print $1;}'| cut -c2-8)"
  if [ "$cmd" = "success" ]; then
    echo "  Passed:   Application Server consistency verified. All checks are successful."
    return 0
  else
    echo "  Error:    Current state of Application Server is not consistent."
    echo "            Connection from Application Server to IDB failed."
    echo "            Please Check the troubleshooting document before upgrade."
    hasErr=1
    return 1
  fi
}

IDBConnectionCheck()
{
    OK_MSG=`${OMNIHOME}/lbin/omnigetmsg 41 38 2>/dev/null`
    CONN_CHECK=`${OMNIHOME}/sbin/omnidbcheck -connection 2>/dev/null | grep ":" | awk -F":" '{print $2}'| awk '{print $NF}'`

    if [ "$OK_MSG" != "$CONN_CHECK" ]; then
        IDBCheckExit "-connection"
        return 1
    else
        echo "  Passed:   IDB connection verified."
        return 0
    fi
}

VerifyHostname()
{
  hname=`hostname`
  numchar=${#hname}
  i=1
  hnameVar=0
  numLabels=`echo $hname | awk -F"." '{print NF-1}'`
  numLabels=` expr $numLabels + 1 `
  UNAME=`uname -a`
  ARCH=`echo ${UNAME} | $AWK '{print $1}'`
  case "${ARCH}" in
  Linux)
        fqdn=`hostname -f`
        ;;
  esac
  cntd=`echo $fqdn | awk -F"." '{print NF-1}'`
  if [ $cntd -lt "2" ]; then
        echo "The hostname resolution might not be correct. Please check your network configuration."
        printf "Press any key to continue installation or E to exit:"
        while read Answer
        do
          case $Answer in E|e)
          echo " Exiting the installation."
          exit 1
          ;;
          * )
          break
          ;;
          esac
        done
  fi

  if [ "$numchar" -le 1 ]; then
    echo "  Error:    Hostname should contain more than one character."
    hnameVar=` expr $hnameVar + 1 `
  fi

  CHAR_UNDERSCORE="_"
  if test "${hname#*$CHAR_UNDERSCORE}" != "$hname"; then	
    echo "  Error:    Hostname should not contain underscore."	
    hnameVar=` expr $hnameVar + 1 `
  fi 
  
  if [ "${#hname}" -gt 60 ]; then
    echo "  Error:    Hostname label length must not be more than 60 characters."
    hnameVar=` expr $hnameVar + 1 `
  fi
  if [ "${hnameVar}" -ge 1 ]; then
    hasErr=1  
    return 1
  else
    echo "  Passed:   Hostname restrictions verified."
    return 0
  fi
}

VerifyOpenFileLimit()
{
      CMD_ULIMIT_n="ulimit -n"

      if [ "$AddOptRS" = "Yes" ]; then
        usr=${RSPGUSER}
      else
        usr=${PGOSUSER}
      fi
      
      Limit=`su - ${usr} -c "$CMD_ULIMIT_n" 2>/dev/null | $AWK -F" " '{ print $1 }'`
      resultLimit=$?
      LimitRoot=`$CMD_ULIMIT_n 2>/dev/null | $AWK -F" " '{ print $1 }'`
      if [  "$?" -eq 0 -a "$resultLimit" -eq 0  ]; then
        if [ "$Limit" != "unlimited" ] && [ "$LimitRoot" != "unlimited" ]  &&  [ "$Limit" -lt 8192 ] && [ "$LimitRoot" -lt 8192 ]; then
          echo "  Error:    The maximum limit of open files is ${Limit} for ${usr} and ${LimitRoot} for root user."
          echo "            Please increase the open file limit to minimum 8192 for ${usr} and root user."
          hasErr=1
          return 1
        elif [ "$Limit" != "unlimited" ] && [ "$Limit" -lt "8192" ]; then
          echo "  Error:    The maximum limit of open files is ${Limit}."
          echo "            Please increase the open file limit to minimum 8192 for ${usr} user."
          hasErr=1
          return 1
        elif [ "$LimitRoot" != "unlimited" ] && [ "$LimitRoot" -lt 8192 ]; then
          echo "  Error:    The maximum limit of open files is ${LimitRoot}."
          echo "            Please increase the open file limit to minimum 8192 for root user."
          hasErr=1
          return 1
        else
          echo "  Passed:   Open file limit restriction verified."
        fi
      else
        echo "  Error:    Open file limit cannot be retrieved."
      fi
}

CheckCalculator()
{
  which bc 2>/dev/null 1>&2 
  retval=`echo $?`
  if [ ${retval} -eq 1 ]; then
    echo "  Error:    Basic command line calculator (bc) is not in the path. Exiting the installation."
    exit 1 
  fi
}

CheckLongFileNameSupport()
{
   dp_dir="/opt"
        if [ -d "$dp_dir" ]
        then
            output=`getconf NAME_MAX $dp_dir`
            ret=`echo $?`
            if [  ${ret} -eq 0 ]; then
                if [ $output -lt 1 ]; then
                echo "  Warning:  Please check if long filenames are supported for the directory ${dp_dir}."
                hasWarn=1
                fi
            fi
        fi
        
    dp_dir="/var"
        if [ -d "$dp_dir" ]
        then
            output=`getconf NAME_MAX $dp_dir`
            ret=`echo $?`
            if [  ${ret} -eq 0 ]; then
                if [ $output -lt 1 ]; then
                echo "  Warning:  Please check if long filenames are supported for the directory ${dp_dir}."
                hasWarn=1
                fi
            fi
        fi
        
    dp_dir="/etc"
        if [ -d "$dp_dir" ]
        then
            output=`getconf NAME_MAX $dp_dir`
            ret=`echo $?`
            if [  ${ret} -eq 0 ]; then
                if [ $output -lt 1 ]; then
                echo "  Warning:  Please check if long filenames are supported for the directory ${dp_dir}."
                hasWarn=1
                fi
            fi
        fi
}

PreRequisiteCheck()
{
  hasErr=0
  hasWarn=0
  UNAME=`uname -s`
  
  `umask 022 2>/dev/null`
  if [ $? -ne 0 ]; then
    echo "  Error:    Could not set the umask value to 022. Please check the system permission and restart the installation."
    hasErr=1
  fi
  
  if [ -f "$OMNI_LBIN/mmd" -o "$AddOptCM" = "Yes" ]; then
    VerifyHostname
  fi

  if [ "${skipOpenFileLimitCheck}" -ne 1 ]; then
      VerifyOpenFileLimit
  fi

  latestVersion=`echo $VERSION | awk -F"." '{ print $2 $3 }'` 
  if [ $CMUpgrade = "Yes" ] && [ $Old_Version -lt $latestVersion ]; then               #execute only if CM upgrade
        flagService=1
        service_stop=1
        service_status=`${OMNIHOME}/sbin/omnisv status 2>/dev/null`
        if [ "$?" -eq 0 ]; then
          flagService=0
        else
          service_stop=0
          service_start=`${OMNIHOME}/sbin/omnisv -start 2>/dev/null`
          if [ "$?" -eq 0 ]; then
            flagService=0
          else
            echo "  Error:    ${SHORTPRODUCTNAME} services cannot be started. Please refer the troubleshooting documentation and correct the setup and try upgrade again."
            checkCM=1
            return 1
          fi
        fi
        if [ "$flagService" -eq 0 ]; then
          CellNameCheck
          IDBConnectionCheck
          ASConsistencyCheck
          ECCStatusCheck
          #IDBPrecheck required only for DP version less than 10.70
          IsDPOBVersionlessThan 10.60
          if [ "$?" = 1 ]; then
           IDBUpgradePreCheck
          fi
          
        fi
        if [ "$service_stop" -eq 0 -a "$hasErr" -eq 1 ]; then
          stopCmd=`${OMNIHOME}/sbin/omnisv -stop 2>/dev/null`
        fi
        if [ "$NoVerifyPeer" != "Yes" ]; then
             ExecutePrereqScript
        fi

        if [ "$NoVerifyAppServerCert" != "Yes" ]; then
             VerifyAppServerCert
        fi       
  fi

  CheckLongFileNameSupport

  if [ ${hasErr} -eq 1 ]; then
    checkCM=1
  elif [ ${hasWarn} -eq 1 ]; then
    checkCM_optional=1
  elif [ ${hasErr} -eq 0 -a ${hasWarn} -eq 0 ]; then
  echo "  "
  echo "  Validating system requirements completed successfully."
  fi
}

IDBCheckExit()
{
    ErrMsg=$1
    echo "  Error:    Omnidbcheck ${ErrMsg} fails with error."
    echo "            Please check the troubleshooting document before upgrade."
    hasErr=1
}

IDBPreUpgradeConsistencyCheck()
{
    echo "  "
    echo "  Validating IDB pre upgrade consistency..."
    echo "  "

    OK_MSG=`${OMNIHOME}/lbin/omnigetmsg 41 38 2>/dev/null`
    SCHEMA_CONSISTENCY=`${OMNIHOME}/sbin/omnidbcheck -schema_consistency 2>/dev/null | grep ":" | awk -F":" '{print $2}'| awk '{print $NF}'`
    if [ "$OK_MSG" != "$SCHEMA_CONSISTENCY" ];then
        IDBCheckExit "-schema_consistency"
        return 1
    fi

    DB_FILES_CHECK=`${OMNIHOME}/sbin/omnidbcheck -verify_db_files 2>/dev/null | grep ":" | awk -F":" '{print $2}'| awk '{print $NF}'`
    if [ "$OK_MSG" != "$DB_FILES_CHECK" ];then
        IDBCheckExit "-verify_db_files"
        return 1
    fi

    echo "  Passed:   IDB consistency verified. All IDB checks are successful."
    return 0

}

IDBFullBackupCheck()
{
    if [ $idbBackupCheck -ne 0 ]; then
        validateIDBBackupScript="${SrcDir}/linux_x86_64/upgrade/validateidbbackup.sql"
        if [ -f $validateIDBBackupScript ]; then
	    IDBFULLBACKUP_DATA=`/opt/omni/sbin/omnidbutil -run_script $validateIDBBackupScript -detail`
	    backUpStatusHeader=`echo $IDBFULLBACKUP_DATA | cut -d' ' -f6`
	    backUpStatus=`echo $IDBFULLBACKUP_DATA | cut -d' ' -f8`
	    if [ "$backUpStatusHeader" = "validate_idb_backup" -a "$backUpStatus" != "NOT_FOUND" ]; then
	        echo "  Passed:   IDB backup within last 3 days found"
	    else
	        UserInputOnNoIDBBackup
	    fi
        else
	    UserInputOnNoIDBBackup
	fi
    fi
}

UserInputOnNoIDBBackup()
{
    echo "  Error:    No IDB full backup found for the last 3 days"
    printf "  Do you want to continue with the upgrade without an IDB backup [Y/N] : "
    while read Answer
        do
        case $Answer in
            Y|y|yes|Yes|YES)
                    break
        ;;
            N|n)
               echo "Exiting the installation"
               exit 0
        ;;
            * )
               echo "Please provide the correct option (Y/N)"
        ;;
        esac
        done
}

CheckUpgradePort()
{
    # check for port 3612 being free or not since its used during postgres version upgrade
    upgradePort=$1
    L_PORT=`${NETSTAT} -an | grep -w ${upgradePort} | grep LISTEN`
    SERVICES=/etc/services
    if [ "${L_PORT}" ]; then
        echo "  Error:    port ${upgradePort} is already in use, aborting upgrade..."
        exit 0
    else
        echo "  Passed:   port ${upgradePort} is available for use"
    fi
}

ECCStatusCheck()
{
    installedDPVersion=`echo $DPOBVersion| cut -d'.' -f 2 | bc`
    if [ $installedDPVersion -lt 10 ]; then
        CSFile=/etc/opt/omni/client/cell_server
        if [ -f "${CSFile}" ]; then
            CMname=`cat $CSFile`
            ECCData='/opt/omni/bin/omnicc -encryption -status $CMname'
            ECCStatus=`eval $ECCData | grep -i $CMname | awk -F" " '{ print $2}'`
            if [ "$ECCStatus" = "true" ]; then
                echo "  Error:   ECC is enabled, please disable ECC before upgrading"
                hasErr=1
                return 1
            fi
        else
            echo "  Error:   Cannot perform ECC check as Cell Manager name not found"
            hasErr=1
            return 1
        fi
    fi
}

IDBUpgradePreCheck()
{
    echo "  "
    echo "  Note:     It is recommended to have a snapshot of the Cell Manager before upgrading."
    IDBPreUpgradeConsistencyCheck
    CheckUpgradePort ${PGUPGRADEPORT}
    CheckhpdpHomeExists
    IDBFullBackupCheck
}

CheckhpdpHomeExists()
{
    if [ -d ${HPDPHOME} ]; then
        echo "  Passed:   Directory ${HPDPHOME} exists"
        return 0
    else
        echo "  Error:    Directory ${HPDPHOME} not found , aborting upgrade..."
        hasErr=1
        return 1
    fi
}

Check1003Installed()
{
    if [ "${BDL_VERSION}" = "A.10.04" ] && [ "${DPOBVersion}" != "A.10.03" ]; then
        echo "  Upgrade to ${BRIEFPRODUCTNAME} ${BDL_VERSION} is supported only from A.10.03 version."
        echo "  Exiting installation..."
        exit;
    fi
}

EnableDebugs()
{
  flagDebug=1
  envSet=`env|grep -w "OB2DBG" | $AWK -F'=' '{print $2}' | sed 's/"//g'`
  if [ "$envSet" != "" ]; then
    flagDebug=0
  fi
  previousVersion=`echo $DPOBVersion | cut -c 3-`
  latestVersion=`echo $VERSION | cut -c 3-`

  if [ -f "$OMNI_LBIN/mmd" ]; then
    debugFilee="upgrade_$previousVersion"
    to="_to_"
    debugFile1="$debugFilee$to"
  else
    debugFile1="install_"
  fi

  debugFile="$debugFile1$latestVersion"
  export OB2DBG="1-300 $debugFile"
}

SecurityOptions()
{
  if [ "${SEC_DATA_COMM}" != "1" -o "${AUDITLOG}" != "1" ]; then
    printf "\n  By not giving '-secure_data_comm' and '-auditlog' options, you are \n"
    printf "  disabling or bypassing security features, thereby exposing the system to \n"
    printf "  increased security risks. By not using these options, you understand and \n"
    printf "  agree to assume all associated risks and hold Micro Focus harmless for the same \n"
    printf "  Do you want to proceed without enabling '-secure_data_comm' and '-auditlog'? [Y/N]:"
        getAnswerEx
        retAns=$?
    if [ ${retAns} -eq 1 ]; then
      return 1
    else
      exit 1
    fi
  fi
}

BackupDBFiles()
{
    # Backup of idb and related files since they are removed during upgrade
    PGHOME=/opt/omni/idb
    PGJDBC_HOME=/opt/omni/AppServer/modules/system/layers/base/org/postgresql
    PGVERSIONFILE=/var/opt/omni/server/db80/pg/PG_VERSION

    # backup existing idb
    if [ -d ${PGHOME} ]; then
        PGVERSION_OLD=$1
        PGHOME_OLD=${OMNIHOME}/idb_${PGVERSION_OLD}
        if [ -d ${PGHOME_OLD} ]; then
	    rm -rf ${PGHOME_OLD}/*
	    cp -rp ${PGHOME}/* ${PGHOME_OLD}
        else
            cp -rp ${PGHOME} ${PGHOME_OLD}
        fi

	# backup existing jdbc driver
	if [ -d ${PGJDBC_HOME}  ]; then
	    PGJDBC_HOME_OLD=${OMNIHOME}/postgresql_${PGVERSION_OLD}
	    if [ -d ${PGJDBC_HOME_OLD} ]; then
	        rm -rf ${PGJDBC_HOME_OLD}/*
	        cp -rp ${PGJDBC_HOME}/* ${PGJDBC_HOME_OLD}
	    else
	        cp -rp ${PGJDBC_HOME} ${PGJDBC_HOME_OLD}
	    fi
	else
	    echo "Warning : Postgres JDBC Driver not found"
	fi
    else
	echo "Database binaries not found, aborting upgrade..."
	exit 0
    fi

}

# main part

InitializeVariables "$@"

LoggingInit

BrandingInit

BrandingInitVariables

CheckCalculator

ProcessObsolescence

if [ -f "$OMNI_LBIN/mmd" -o "$AddOptCM" = "Yes" ]; then
  if [ $Old_Version -lt 1050 ]; then
    SecurityOptions
  fi
  EnableDebugs
fi

if [ ! -z "$DPOBVersion" ]; then
  DPVersion=$DPOBVersion
  export DPVersion
else
  DPVersion=""
  export DPVersion
fi

if [ "$collectTelemetryData" -eq 1 ]; then
   if [ -f /opt/omni/sbin/omnidbutil ]; then
       PATH=$PATH:/opt/omni/idb/bin
       isCustomerSubscribed
       subscriptionValue="$dbValue"
   fi
fi

if [ "$Minor" = "Add" ]; then
  InstallMinorMinor
else
  if [ "$Minor" = "Remove" ]; then
    RemoveMinorMinor
  fi  
fi
if [ "$PatchAdd" = "Add" ]; then
  InstallPatch
fi

if [ "$AddOptRS" = "Yes" ]; then
  checkCM=0
  checkCM_optional=0
  checkCMmem=0
  OUTPUT=0

  if [ "$AddOptCM" != "Yes" ];then
    if [ "${SEC_DATA_COMM}" != "" ]; then
        echo "Secure Data Communication cannot be enabled during RS installation"
        SEC_DATA_COMM=""
    fi 
    if [ "${AUDITLOG}" != "" ]; then
        echo "Audit logs cannot be enabled during RS installation"
        AUDITLOG=""
    fi
    if [ "${AUDITLOG_RETENTION}" != "" ]; then
        echo "Audit log retention value cannot be modified during RS installation"
        AUDITLOG_RETENTION=""
    fi 	
  fi
 
  echo "  Validating System requirements..."
  echo "  "
  RSPGUSER="rsdb"
  CheckOSuser ${RSPGUSER}
  CheckKernel
  CheckDiskSpace
  CheckCMSystemReq
  if [ "$NoPreReqCheck" != "Yes" ]; then
    PreRequisiteCheck
  fi

if [ "${checkCM}" -eq 1 ]; then
  echo "  Some of the pre-requisites are not satisfied, exiting the installation."
  exit 1
elif [ "${checkCMmem}" -eq 1 ]; then
  echo "  Available system memory is less than required memory. If you wish to continue the installation, please increase the memory to 16GB."
  echo "  "
  exit 1
else
  if [ "${checkCM_optional}" -eq 1 ]; then
    printf "  Some of the system requirements are not satisified, press any key to continue installation or E to exit:"
    while read Answer
    do
      case $Answer in
        E|e)
          echo "  Exiting the installation."
          exit 1
          ;;
        * )
          break
          ;;
      esac
    done
  fi
fi  
   RS_setup
fi

InitializeAvailablePacketList

CheckTasks


# at this point we have AddOptCM, PacketsList, AddOptIS (for CM, Client, IS), Uninstall
if [ "Extract" != "Yes" ]; then
  SaveCurrentState
fi

if [ "$package" = "" ]; then
  CheckWork
fi

if [ "$collectTelemetryData" -ne 0 -a $CMUpgrade = "Yes" ]; then
    getTelemetryData
    updateTelemetryDataInDB
fi

if [ "$Uninstall" = "Yes" -o "$Reinstall" = "Yes" ]; then
  UninstallAll
fi

if [ "$AddOptCM" = "Yes" -a "$PatchAdd" != "Add" ]; then
  StartMaintenanceMode
  if [ "$AddOptIS" = "Yes" ]; then
    CMIS="Yes"
    CMInstall $CMIS
  else
    CMInstall
  fi
  SaveCurrentState
fi
StopMaintenanceMode
if [ "$AddOptIS" = "Yes" -a "$PatchAdd" != "Add" ]; then
  CheckWork
  ISInstall
  SaveCurrentState
fi

if [ "$Packets" != "" -a "$package" = "" ]; then
  CheckWork
  ClientInstall
  SaveCurrentState
elif [ "$Packets" != "" -a "$package" != "" ]; then
  ExtractPacket
fi

rm -rf /var/opt/omni/tmp/omni_tmp
rm -rf /tmp/omni_tmp
rm -f /tmp/regencert

if [ -f "$OMNI_LBIN/mmd" -o "$AddOptCM" = "Yes" ]; then
  unset OB2DBG

  OUTPUTStop=`/opt/omni/sbin/omnisv stop 2>/dev/null`
  if [ "$flagDebug" -eq 0 -a "$envSet" != "" ]; then
    export OB2DBG="$envSet"
  fi
  OUTPUTStart=`/opt/omni/sbin/omnisv start 2>/dev/null`
fi

if [ "$?" -ne 0 ]; then
  echo "${SHORTPRODUCTNAME} services cannot be started. Please refer the troubleshooting documentation and start the services."
else
   #Add the new user right to DpKeyCLoak DB when the upgrade is from a version
   #less than 10.50, and equal or greater than 10.03
   IsDPOBVersionlessThan 10.50
   rc1=$?
   IsDPOBVersionlessThan 10.02		#greater than 10.02, i.e. 10.03 & higher versions
   rc2=$?
   if [ $rc1 -eq 1 -a $rc2 -eq 0 ]; then
      echo "Adding Roles .."
      AddRoles
   fi
fi

echo
if [ "$ErrorHappened" = "" ]; then
  echo "  Installation/upgrade session finished."
  if [ $CMUpgrade = "Yes" ]; then
       GREPlugin=appserver_vepagre_plugin
       cellinfo=/etc/opt/omni/server/cell/cell_info
       #check if the file exist
       if [ -f "${cellinfo}" ]; then
          while IFS='' read -r LINE || [ -n "$LINE" ];
          do
            HOSTINFO=`echo ${LINE} | grep ${GREPlugin}`
            if [ "$HOSTINFO" != "" ]; then
               HOSTIP=`echo "${HOSTINFO}" | awk '{print $2}'`
               echo "Reregistering $HOSTIP..."
               /opt/omni/bin/omnicc -upgrade_greplugin "$HOSTIP" 1>&2
               rc=`echo $?`
               if [ "$rc" != "0" ]; then
                  echo "ERROR: Failed to Upgrade GRE plugin for ${HOSTIP} (Return code = $rc)"
                  echo "Please run the command '/opt/omni/bin/omnicc -upgrade_greplugin "$HOSTIP"' on Cell Manager  after the upgrade of all GRE mount proxies."
               fi
            fi
            done  < "${cellinfo}"
         else
            echo "$cellinfo not found"
         fi
     fi
else
  echo "  Installation/upgrade session finished with errors."
fi


