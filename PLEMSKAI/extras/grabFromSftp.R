# obtain results from sftp server
coorKeyFileName <- "G:/StudyResults/mskai/study-coordinator-ndorms.dat"
userName <- "study-coordinator-ndorms"
localFolder <- "G:/StudyResults/mskai"
#dir.create(localFolder)
sftpDirectory <- "MSKAI_PLE_Collaborator_Results"

connection <- OhdsiSharing::sftpConnect(coorKeyFileName, userName)

OhdsiSharing::sftpLs(connection)
OhdsiSharing::sftpCd(connection, sftpDirectory)
files <- OhdsiSharing::sftpLs(connection)
OhdsiSharing::sftpGetFiles(connection, files[[1]], localFolder = localFolder)
OhdsiSharing::sftpDisconnect(connection)
