# ltsvparser

## NAME
ltsvparser.awk - AWK based parser from LTSV (Labeled Tab Separated Value) to TSV or JSON

## SYNOPSIS

### LTSV to JSON
	$ cat ltsvdata.txt | ltsvparser.awk
	{
		"datetime":"2014/07/11 19:00",
		"url":"https://github.com/ps-labo/",
		"description":"my page",
		"count":100
	}
	{
		"datetime":"2014/07/11 19:30",
		"url":"https://github.com/ps-labo/ltsvparser",
		"description":"ltsvparser",
		"count":200
	}

### LTSV to JSON with highlight some field (highlight=xxx)
	$ cat ltsvdata.txt | ./ltsvparser.awk highlight=datetime
	{
	  "datetime":"2014/07/11 19:00",
	  "url":"https://github.com/ps-labo/",
	  "description":"my page",
	  "count":100
	}
	{
	  "datetime":"2014/07/11 19:30",
	  "url":"https://github.com/ps-labo/ltsvparser",
	  "description":"ltsvparser",
	  "count":200
	}

### LTSV to TSV (format=tsv)
	$ cat ltsvdata.txt | ltsvparser.awk format=tsv
	datetime	url	description	count
	2014/07/11 19:00	https://github.com/ps-labo/	my page	100
	2014/07/11 19:30	https://github.com/ps-labo/ltsvparser	ltsvparser	200

### LTSV to TSV with highlight some field
	$ cat ltsvdata.txt | ltsvparser.awk format=tsv highlight=count
	datetime	url	description	count
	2014/07/11 19:00	https://github.com/ps-labo/	my page	100
	2014/07/11 19:30	https://github.com/ps-labo/ltsvparser	ltsvparser	200

### LTSV to TSV with change field order (label=xxx,xxx)
	$ cat ltsvdata.txt | ltsvparser.awk format=tsv label=datetime,count,description
	datetime	count	description
	2014/07/11 19:00	100	my page
	2014/07/11 19:30	200	ltsvparser

### LTSV to LTSV with change field order (format=ltsv)
	$ cat ltsvdata.txt | ltsvparser.awk format=ltsv label=datetime,count,description
	datetime:2014/07/11 19:00	count:100	description:my page
	datetime:2014/07/11 19:30	count:200	description:ltsvparser

### TSV to JSON/LTSV
	$ cat tsvdata.txt
	datetime	url	description	count
	2014/07/11 19:00	https://github.com/ps-labo/	my page	100
	2014/07/11 19:30	https://github.com/ps-labo/ltsvparser	ltsvparser	200
	
	$ cat tsvdata.txt | ltsvparser.awk tsv_label=datetime,url,description,count
	{
		"datetime":"2014/07/11 19:00",
		"url":"https://github.com/ps-labo/",
		"description":"my page",
		"count":100
	}
	{
		"datetime":"2014/07/11 19:30",
		"url":"https://github.com/ps-labo/ltsvparser",
		"description":"ltsvparser",
		"count":200
	}
	
	$ cat tsvdata.txt | ltsvparser.awk tsv_label=datetime,url,description,count format=ltsv
	datetime:2014/07/11 19:00	url:https://github.com/ps-labo/	description:my page	count:100
	datetime:2014/07/11 19:30	url:https://github.com/ps-labo/ltsvparser	description:ltsvparser	count:200

### apache combined log to JSON, LTSV, TSV
	$ cat access_log.sample 
	1.2.3.4 - - [13/Jul/2014:22:04:26 +0900] "POST /cgi-bin/test.cgi?param=value1&param2=value2 HTTP/1.0" 200 418 "http://example.com/" "TwilioProxy/1.1"
	5.6.7.8 - - [13/Jul/2014:22:05:07 +0900] "GET /twilio/outgoing-emergency-call.php HTTP/1.1" 200 1280 "http://example.com/cgi-bin/test.cgi?param=value&param2=value2" "curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.13.1.0 zlib/1.2.3 libidn/1.18 libssh2/1.2.2"
	
	$ cat access_log.sample  | ./ltsvparser.awk mode=apache
	{
		"host":"1.2.3.4",
		"ident":"-",
		"user":"-",
		"time":"[13/Jul/2014:22:04:26 +0900]",
		"req":"POST /cgi-bin/test.cgi?param=value1&param2=value2 HTTP/1.0",
		"status":200,
		"size":418,
		"referer":"http://example.com/",
		"ua":"TwilioProxy/1.1"
	}
	{
		"host":"5.6.7.8",
		"ident":"-",
		"user":"-",
		"time":"[13/Jul/2014:22:05:07 +0900]",
		"req":"GET /twilio/outgoing-emergency-call.php HTTP/1.1",
		"status":200,
		"size":1280,
		"referer":"http://example.com/cgi-bin/test.cgi?param=value&param2=value2",
	}
	
	$ cat access_log.sample  | ./ltsvparser.awk mode=apache format=ltsv
	host:1.2.3.4	ident:-	user:-	time:[13/Jul/2014:22:04:26 +0900]	req:"POST /cgi-bin/test.cgi?param=value1&param2=value2 HTTP/1.0"	status:200	size:418	referer:"http://example.com/"	ua:"TwilioProxy/1.1"
	host:5.6.7.8	ident:-	user:-	time:[13/Jul/2014:22:05:07 +0900]	req:"GET /twilio/outgoing-emergency-call.php HTTP/1.1"	status:200	size:1280	referer:"http://example.com/cgi-bin/test.cgi?param=value&param2=value2"	ua:"curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.13.1.0 zlib/1.2.3 libidn/1.18 libssh2/1.2.2"
	
	$ cat access_log.sample  | ./ltsvparser.awk mode=apache format=tsv
	host	ident	user	time	req	status	size	referer	ua
	1.2.3.4	-	-	[13/Jul/2014:22:04:26 +0900]	"POST /cgi-bin/test.cgi?param=value1&param2=value2 HTTP/1.0"	200	418	"http://example.com/"	"TwilioProxy/1.1"
	5.6.7.8	-	-	[13/Jul/2014:22:05:07 +0900]	"GET /twilio/outgoing-emergency-call.php HTTP/1.1"	200	1280	"http://example.com/cgi-bin/test.cgi?param=value&param2=value2"	"curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.13.1.0 zlib/1.2.3 libidn/1.18 libssh2/1.2.2"

## AUTHOR
Kazuhiro INOUE

## LICENSE
This script is free softwere.


