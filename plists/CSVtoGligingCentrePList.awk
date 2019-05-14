# NOTES:
# - MasterSiteList.csv should be taken as the template.
# - The Notes column is not usable with awk and this version of the script
# - When exporting from Excel (or Google Spreadsheet), the used locale must be Canadian English, to have '.' instead of ','
#   for decimal separator. This is to prevent confusion with field separator.

BEGIN {
    FS = "\"?,\"?"
    OFS = ""

    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    print "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
    print "<plist version=\"1.0\">"
    print "<dict>"
}

{
    if ( NR > 1 && $1 != "") {
        print "\t<key>",$1,"</key>"
        print "\t<dict>"
		print "\t\t<key>Latitude</key>"
		print "\t\t<real>",$3,"</real>"
		print "\t\t<key>Longitude</key>"
		print "\t\t<real>",$4,"</real>"
		print "\t\t<key>Defunct</key>"
		print "\t\t<",( $2 != "" ) ? tolower($2) : "false","/>"
		print "\t\t<key>FullName</key>"
		print "\t\t<string>",$5,"</string>"
		print "\t\t<key>Region</key>"
		print "\t\t<string>",$6,"</string>"
        print "\t\t<key>SummerUnit</key>"
        print "\t\t<",($8 != "") ? tolower($8) : "false","/>"
        print "\t\t<key>SourceLine</key>"
        print "\t\t<real>",NR,"</real>"
	    print "\t</dict>"
    }
}

END {
    print "</dict>"
    print "</plist>"
}
