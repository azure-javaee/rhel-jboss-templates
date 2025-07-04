#!/bin/sh
set -Eeuo pipefail

log() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line" >> /var/log/jbosseap.install.log
    done
}

# Parameters
eapRootPath=$1                                      # Root path of JBoss EAP
jdbcDataSourceName=$2                               # JDBC Datasource name
jdbcDSJNDIName=$(echo "${3}" | base64 -d)           # JDBC Datasource JNDI name
dsConnectionString=$(echo "${4}" | base64 -d)       # JDBC Datasource connection String
databaseUser=$(echo "${5}" | base64 -d)             # Database username
databasePassword=$(echo "${6}" | base64 -d)         # Database user password
isManagedDomain=$7                                  # true if the server is in a managed domain, false otherwise
isSlaveServer=$8                                    # true if it's a slave server of a managed domain, false otherwise
enablePswlessConnection=${9}                        # Enable passwordless connection
uamiClientId=${10}                                  # UAMI display name

# Create JDBC driver and module directory
jdbcDriverModuleDirectory="$eapRootPath"/modules/com/microsoft/sqlserver/main
mkdir -p "$jdbcDriverModuleDirectory"

# Download JDBC driver
jdbcDriverVersion=11.2.1.jre8
jdbcDriverName=mssql-jdbc-${jdbcDriverVersion}.jar
curl --retry 5 -Lo ${jdbcDriverModuleDirectory}/${jdbcDriverName} https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${jdbcDriverVersion}/${jdbcDriverName}

# Create module for JDBC driver
jdbcDriverModule=module.xml
cat <<EOF >${jdbcDriverModule}
<?xml version="1.0" ?>
<module xmlns="urn:jboss:module:1.1" name="com.microsoft.sqlserver">
  <resources>
    <resource-root path="${jdbcDriverName}"/>
  </resources>
  <dependencies>
    <module name="javaee.api"/>
    <module name="sun.jdk"/>
    <module name="ibm.jdk"/>
    <module name="javax.api"/>
    <module name="javax.transaction.api"/>
    <module name="javax.xml.bind.api"/>
  </dependencies>
</module>
EOF
chmod 644 $jdbcDriverModule
mv $jdbcDriverModule $jdbcDriverModuleDirectory/$jdbcDriverModule

# Register JDBC driver
if [ $isManagedDomain == "false" ]; then
    # Register JDBC driver
    sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
    "/subsystem=datasources/jdbc-driver=sqlserver:add(driver-name=sqlserver,driver-module-name=com.microsoft.sqlserver,driver-xa-datasource-class-name=com.microsoft.sqlserver.jdbc.SQLServerXADataSource)" | log
elif [ $isSlaveServer == "false" ]; then
    # Register JDBC driver
    sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
    "/profile=ha/subsystem=datasources/jdbc-driver=sqlserver:add(driver-name=sqlserver,driver-module-name=com.microsoft.sqlserver,driver-xa-datasource-class-name=com.microsoft.sqlserver.jdbc.SQLServerXADataSource)" | log
fi

# Create data source
if [ "$(echo "$enablePswlessConnection" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  dsConnectionString="$dsConnectionString;authentication=ActiveDirectoryMSI;msiClientId=${uamiClientId}"
  if [ $isManagedDomain == "false" ]; then
      echo "data-source add --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter" | log
      sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
      "data-source add --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter"
  elif [ $isSlaveServer == "false" ]; then
      echo "data-source add --profile=ha --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter" | log
      sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
      "data-source add --driver-name=sqlserver --profile=ha --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter"
  fi
else
  if [ $isManagedDomain == "false" ]; then
      echo "data-source add --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter" | log
      sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --echo-command \
      "data-source add --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter"
  elif [ $isSlaveServer == "false" ]; then
      echo "data-source add --profile=ha --driver-name=sqlserver --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=*** --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter" | log
      sudo -u jboss $eapRootPath/bin/jboss-cli.sh --connect --controller=$(hostname -I) --echo-command \
      "data-source add --driver-name=sqlserver --profile=ha --name=${jdbcDataSourceName} --jndi-name=${jdbcDSJNDIName} --connection-url=${dsConnectionString} --user-name=${databaseUser} --password=${databasePassword} --validate-on-match=true --background-validation=false --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.mssql.MSSQLExceptionSorter"
  fi
fi