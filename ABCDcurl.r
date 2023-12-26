Rebol [Title: "Download Bhavcopy"
   file: ABCDcurl.r
   author: "Satish Joshi"
   rights: 'BSD
   date: 20-June-2014
   purpose: { To download bhavcopy from NSE BSE AMFI }
   Changes: 	{Earlier version used to process scrips of all series as they were. This led to duplicate entries.
   		Lupin EQ and Lupin N1 were being treated as Lupin so N1 series prices would replace EQ series prices.
   		Now we keep scrips of EQ and BE series as they are. Other series are appended to the symbol.
   		Lupin N1 will become Lupin_N1.

   		03-12-2015 
   		1. NSE changed url for indices. Changed code to download indices
   		2. Added option to download NSE bhavcopy and indices seperately.
   		
   		16-01-2016
   		1. HTTP timeout increased to 10 secs.
   		2. Date controls incorporated
   		3. Missing data files captured in log.txt
   		4. Week ends skiped (default) with option
   		5. No download if data file exists
   		
   		20-01-2016
   		1. Added Options for OI, Rename futures, Indices and Headers
   		2. Added Repeat 5 for connecting to server that is stabilising download
   		3. Added Help feature.
   		
   		20-12-2018
   		Changed all BSE URL to https:// Used curl.exe to download files. Now curl.exe to be bundled with ABCD.
   		
   		21-12-2018
   		Added support for BSE Mutual Fund NAV download.

		20-12-2019
		Added support for processing downloaded files only
   		
		14-01-2020 
		NSE URL for Bhavcopy changed to "http://www1.nseindia.com/content/historical/EQUITIES/
		-L added to Curl command for redirection
		to do- change in url for deliverables
		
		11-01-2021
		1.Module for Interest rate futures incorporated
		2.New URL for NSE Bhavcopy added
		3.
   		}
]

system/schemes/http/timeout: 00:00:10
;system/schemes/http/user-agent: "Mozilla/5.0"
do %./form-date.r								;Include form-date. for manipulating date format


Std: Ed: Sd: now/date 								; initialise Start and End Date with current Date


settings: ["yes" "no" "no" "no" "no" "yes" "no" "no" "no" "no" "no" "no" "no" "no" "no" "no" "no" "no" "no" "no"]				; Initialise settings


Folders: [%./NSE %./NSEFO %./NSECUR %./BSE %./BSEFO %./BSECUR %./AmfiMF %./NSEIRF]			; Folders where data will be saved.
foreach folder Folders [if not exists? folder [make-dir folder]]		; Create folders if they do not exist


either error?  try [change settings read/lines %ABCD.ini]				; read settings from ini file  
	[write/lines %ABCD.ini settings][				; probe settings
]

ToDMY: func ["Function to convert rebol date to dd-mm-yyyy format. This was created by Satish Joshi" dt[date!]
	    ] [return trim/all reform [next form dt/day + 100 "-" next form dt/month + 100 "-" dt/year]
	]

csv-import: func [ "Function to Import a CSV file transforming it in a series." file [file!] "CSV file"    /local temp temp2 ] [
    temp: read/lines file		
    temp2: copy []								;initialise temp2 as empty
    foreach item temp [append/only temp2 (parse/all item ",") ] 		;separate all items in each line at each comma and append to temp2
    	return temp2
    ]

mf-import: func [ "Function to Import a CSV file transforming it in a series." file [file!] "CSV file"    /local temp temp2 ] [
    temp: read/lines file		
    temp2: copy []								;initialise temp2 as empty
    foreach item temp [append/only temp2 (parse/all item ";") ] 		;separate all items in each line at each comma and append to temp2
    	return temp2
    ]
    
scroll-text: func ["Function to scroll log text in an area" txt] [				;function to scroll log text in an area
		count: to-integer find/tail (to-string size-text txt) "x"
                    if count > 300 [txt/para/scroll/y: 280 - count]
                    show txt
                ]

validate-screen: func ["Function to validate dates entered by user" ][
	fields: reduce [ Onlyfiles Sdate Edate NseBhav Nsei NseDer NseCur Nsed NseiS NseIRF BseBhav BseDer BseCur Weekends  AmfiL AmfiH]		;Read all fields from screen
			
			st: to-date Sdate/text 
			et: to-date Edate/text 
        any [
        	if st > now/date [Alert "Start Date in future? Dude ... I cannot take future Data" Sdate/text: ToDMY now show Sdate return 0]
        	if et < st [Alert "End Date cannot be less than Start Date" Edate/text: ToDMY now show Edate return 0]
        	if et > now/date [Alert "Start Date in future? Dude ... I cannot take future Data" Edate/text: ToDMY now show Edate return 0]
        ] [return 1]
]	                                                                                                                                            

continue: does [throw 'continue]

writesettings: does [write/lines %ABCD.ini settings]

;NSE URL format changed from 1st January, 2019 - https://www.nseindia.com/content/historical/EQUITIES/2019/JAN/cm01JAN2019bhav.csv.zip
;curl -H "Mozilla/5.0 (X11; Linux x86_64; rv:71.0) Gecko/20100101 Firefox/71.0 "
;		-e https://www.nseindia.com/products/content/equities/equities/homepage_eq.htm --url https://www.nseindia.com/content/historical/EQUITIES/2019/JAN/cm03JAN2019bhav.csv.zip -o /ABCD/NSE/cm03JAN2019bhav.csv.zip
;		NSE_Url: rejoin ["curl -H " UserAgent " -e https://www.nseindia.com/products/content/equities/equities/homepage_eq.htm --url "  NSE_Url "-o /ABCD/NSE/cm" Sd "bhav.csv.zip " ]
;        NSE_Url: rejoin ["curl -e https://www.nseindia.com/products/content/equities/equities/archieve_eq.htm --url "  NSE_Url "-o /ABCD/NSE/cm" Sd "bhav.csv.zip " ]
;	-A "RT="z=1&dm=nseindia.com&si=be430a8e-d735-4ba6-96a9-9730e07c0605&ss=k4dhpi2h&sl=0&tt=0&bcn=%2F%2F60062f0c.akstat.io%2F&ul=82wmf"; NSE-TEST-1=1910513674.20480.0000; ak_bmsc=E124E1F820996CAE92E16C5C3F625308B856F876C0050000B6BDFC5D7407F91E~plJELhDyRU/Tkak1snWhhhDLI3pgEBh6N2+cjhTvPpeVDzhaX1xQCDz8gdJ0v1pyE7uXV1jIZWR1lLNXLt9DSFPJfpqJV1yEJvizGBXxvNgttmG039kShyp19lFYCJ00W+l/L8AR+LjrMoc9qeINJ+iqs6Ea7HXLr4tBdG5Wl8kQDhibxwNB2wQ7LVJwUzu3wCVk+uxCa+ygaGtEnqPOuwCcww0D7U+l2BqJi2dDknU4k=; bm_sv=30889A4AC2F6F8E0B11B077D5EBE79F6~i0aMYcdKzrxQj3VSmR9lpXRZvcSL9SIX97Mhx73yRgOsygp1UXodzNSa0lU0rqlRZHU9xYehmY7sKsmSMmQPCOPdKC2dfbW3wUOtzySzg6wj9j+8TEzrk863Z+qxbetaRbs6YZ4P0Dog79zA3YXWZ7pMua7EEHsIhXVFJUSy/l4="
;https://archives.nseindia.com/content/historical/EQUITIES/
; NSE URL from 23rd July, 2021
; https://www1.nseindia.com/content/historical/EQUITIES/2021/JUL/cm19JUL2021bhav.csv.zip
;

;;NSE URL format changed from 1st April, 2023 
;https://www.nseindia.com/api/reports?archives=%5B%7B%22name%22%3A%22CM%20-%20Bhavcopy(csv)%22%2C%22type%22%3A%22archives%22%2C%22category%22%3A%22capital-market%22%2C%22section%22%3A%22equities%22%7D%5D&date=31-Mar-2023&type=equities&mode=single
;https://www.nseindia.com/api/reports?archives=[{%22name"%3A"CM%20-%20Bhavcopy(csv)"%2C"type"%3A"archives"%2C"category"%3A"capital-market"%2C"section"%3A"equities"}]&date=31-Mar-2023&type=equities&mode=single
;https://archives.nseindia.com/products/content/sec_bhavdata_full_22122023.csv

downloadNseBhav: func [Date] [
 	Target: to-file join "./NSE/" [DateYmd "NSE-EQ.txt"]
	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"]] show log	Exit] [

	if not Onlyfiles/data [

	{	
		;url_part1: "https://www.nseindia.com/api/reports?archives=%5B%7B%22name%22%3A%22CM%20-%20Bhavcopy(csv)%22%2C%22type%22%3A%22archives%22%2C%22category%22%3A%22capital-market%22%2C%22section%22%3A%22equities%22%7D%5D&date="
		;url_part2: "&type=equities&mode=single"
		;NSE_Url: rejoin [url_part1 uppercase form-date Date "%Y/%b/"  "cm" Sd "bhav.csv.zip "] 		; format NSE Bhavcopy url
		;NSE_Url: rejoin [url_part1 form-date Date "%d-%b-%Y" url_part2] 		; format NSE Bhavcopy url
		;NSE_Url: rejoin ["https://www.nseindia.com/content/historical/EQUITIES/" uppercase form-date Date "%Y/%b/"  "cm" Sd "bhav.csv.zip "] 		; format NSE Bhavcopy url
	}
		NSE_Url: rejoin ["https://archives.nseindia.com/products/content/sec_bhavdata_full_" form-date Date "%d%m%Y" ".csv"] 		; format NSE Bhavcopy url

		NSE_Url: rejoin ["curl -L -f -k --max-time 10 --url " NSE_Url " -o /ABCD/NSE/cm" DateYmd ".csv" ]

		;			UserAgent: {"User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko"}
		
		either zero? call/wait NSE_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join NSE_Url "^/Downloaded NseBhavcopy Zip^/" scroll-text Log]
				]
				[	write/append %log.txt rejoin [NSE_Url "^/  NSE/EQUITIES/bhavcopy not found " DateYmd "^/"]
					append Log/text join NSE_Url "^/Server made a boo boo ...... NSE Bhavcopy not found- ^/ try manually^/^/" scroll-text Log 
					Exit  
				]
	]

	{
		;Code added for downloading Deliverable data file  - Now commented since delivery data available in new file
		if Oi/data [
			; Current Url of Deliverable --  https://www.nseindia.com/archives/equities/mto/MTO_ddmmyyyy.DAT
			;New url from 1-1-2019 https://www.nseindia.com/archives/equities/mto/MTO_01012019.DAT
			NSED_Url: rejoin ["https://www1.nseindia.com/archives/equities/mto/MTO_" form-date Date "%d%m%Y" ".DAT"] 		; format NSE Deliverable data url
			NSED_Url: rejoin ["curl -f -k --max-time 10 " NSED_Url " -o /ABCD/NSE/MTO" form-date Date "%d%m%Y" ".DAT" ]
		
			either zero? call/wait NSED_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join NSED_Url "^/Downloaded NseDeliverable^/" scroll-text Log]
				]
				[	write/append %log.txt rejoin [NSED_Url "^/  NSE/Deliverable file not found ^/"]
					append Log/text join NSED_Url "^/Server made a boo boo ...... NSE Deliverable file not found- ^/ try manually^/^/" scroll-text Log 
					Exit  
				]
		]
	}

	{
		;Start processing downloaded files
	
		Commented processing for zip file since we are getting .csv file now

		ZipFile: to-file rejoin ["./NSE/cm" Sd "bhav.csv.zip"]		;Create string to call unzip command
		
		either zero? call/wait join  "unzip -d ./NSE/ -o " [ZipFile] [					;extract bhavcopy csv file from zip file			
			if verbose/data [append Log/text "Extracted Bhavcopy^/" scroll-text Log]
		] [	write/append %log.txt rejoin ["Bad zip file - ./NSE/cm" Sd "bhav.csv.zip"]
			append Log/text "Bad zip file.. could not extract Bhavcopy^/^/" show log
			Exit
		]

		;process delivery data file
		if Oi/data [
			DeliveryDatPath: to-file rejoin ["./NSE/MTO" form-date Date "%d%m%Y" ".DAT"]
			DL: True
			DeliveryData: 	csv-import DeliveryDatPath
			foreach line DeliveryData [ if not (line/4 = "EQ") or (line/4 = "BE") or (line/4 = "DR") [clear line]]  
			remove-each line DeliveryData [empty? line]
		]	
		Now start formatting Equity file for import ----
		Current format of quotes in Deliverables file-- first four lines - Information
		 				fifth line onwards -- 
			Record Type,Sr No,Name of Security,Quantity Traded,Deliverable Quantity(gross across client level),% of Deliverable Quantity to Traded Quantity
		 ;  	Current format of quotes in Bhavcopy csv file :   SYMBOL,SERIES,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,TOTTRDQTY,TOTTRDVAL,TIMESTAMP,TOTALTRADES,ISIN,
																1      2   	  3	  4		5	6	  7		8		  9			10		  11		 12       13
    		CsvFilePath: to-file join "./NSE/cm" [Sd "bhav.csv"]         ;Create string to read csv file - precede with date

		format of quotes in Bhavcopy csv file since April 2023
		;SYMBOL, SERIES, DATE1, PREV_CLOSE, OPEN_PRICE, HIGH_PRICE, LOW_PRICE, LAST_PRICE, CLOSE_PRICE, AVG_PRICE, TTL_TRD_QNTY, TURNOVER_LACS, NO_OF_TRADES, DELIV_QTY, DELIV_PER
	   		1        2     3        4           5            6           7          8            9          10           11           12                13         14         15
	}
		
    		CsvFilePath: to-file join "./NSE/cm" [DateYmd ".csv"]         ;Create string to read csv file - precede with date  /ABCD/NSE/cm" form-date Date "%Y-%m-%d" ".csv"
   
    		Quotes: csv-import  CsvFilePath					; Import csv file into block
    		remove  Quotes 							; Delete first line of Quotes
    		foreach line Quotes [if not ((trim line/2) = "EQ") or ((trim line/2) = "BE")  or ((trim line/2) = "DR") [clear line]]
    		remove-each line Quotes [empty? line]

    		foreach line Quotes [quote: copy line
    				Temp2:  form-date (to-date DateYmd) "%Y%m%d"		; Pick timestamp from quote and Change date format
    				line/2:  copy Temp2					; write date in second place
					line: skip line 2					; position at 3rd place
					remove/part line 2					; remove DATE1, PREV_CLOSE,
					line: skip line 3					; position at  LOW_PRICE
					remove/part line 1					; remove LAST_PRICE,
					line: skip line 1					; position at CLOSE_PRICE
					remove/part line 1					; remove AVG_PRICE
		    		if Oi/data [
						line: skip line 1
    					remove/part line 2	
					]
    				clear next line							; Remove everything after Deliverable Volume
					line: head line
    				foreach item line [change item append item ","]			; append comma to each field
					append line newline
    		]

	{    		
    				line/7: copy quote/9					; replace Last with TOTTRDQTY (volume)
    				line: skip line 6						; move to Deliverable volume in line
    				;append line newline 						; append carrige return to Quote
    		if Oi/data [
    			if DL [foreach line DeliveryData [foreach quote Quotes [if found? find line quote/1 [quote: append quote line/6]]]] ;Add Deliverble data to end of line -14th field
    		]

			foreach line Quotes [
    			foreach item line [change item append item ","]			; append comma to each field
				append line newline
			]
	}
		if not Nsed/data [delete CsvFilePath]				; Delete bhavcopy zip if not required
		if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]
    		write/append Target Quotes
		if verbose/data [append Log/text "Created NSE-EQ.txt file^/^/" scroll-text Log]
	{		

		if not Nsed/data [delete Zipfile				; Delete bhavcopy zip if not required
				  if Oi/data [delete DeliveryDatPath]
				if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log]
		]	
	}
	]
]	
    		

downloadNseDer: func [Date] [
		Target: to-file join "./NSEFO/" [DateYmd "NSE-FO.txt"]

	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [
		if not Onlyfiles/data [
			;https://www1.nseindia.com/content/historical/DERIVATIVES/2019/NOV/fo15NOV2019bhav.csv.zip
			NseDer_Url: rejoin ["curl -f -k --max-time 10  --url https://archives.nseindia.com/content/historical/DERIVATIVES/" 
			(uppercase form-date Date "%Y/%b/")  "fo" Sd "bhav.csv.zip"] 		; format NSE DerivativesBhavcopy url
			NseDer_Url: rejoin [NseDer_Url " -o /ABCD/NSEFO/fo" Sd "bhav.csv.zip"]
;				append Log/text join NseDer_Url "^/" scroll-text Log
				
			either zero? call/wait NseDer_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join NseDer_Url "^/Downloaded NSE FO Bhavcopy ^/" scroll-text Log]
				]
				[	write/append %log.txt rejoin [NseDer_Url "^/  NSE Futures/bhavcopy not found ^/"]
					append Log/text join NseDer_Url "^/Server made a boo boo ...... NSE Futures/bhavcopy not found ^/^/" scroll-text Log 
					Exit  
				]
		]
		ZipFilePath:  join "unzip -od ./NSEFO  ./NSEFO/fo" [ Sd "bhav.csv.zip"]		;Create string to call unzip command
		
		either zero? call/wait ZipFilePath [						;extract bhavcopy csv file from zip file
			if verbose/data [append Log/text "Extracted NSE foBhavcopy^/" scroll-text Log]
			] [	write/append %log.txt rejoin ["Bad zip file - ./NSEFO/fo" Sd "bhav.csv.zip"]
				append Log/text "Bad zip file.. could not extract foBhavcopy^/^/" show log
				Exit
		]
;	   	Current format of quotes in foBhavcopy csv file :  
;		INSTRUMENT,SYMBOL,EXPIRY_DT,STRIKE_PR,OPTION_TYP,OPEN,HIGH,LOW,CLOSE,SETTLE_PR,CONTRACTS,VAL_INLAKH,OPEN_INT,CHG_IN_OI,TIMESTAMP,
{
    		if Futures/data [
    			if not exists? %Futures.txt [write %Futures.txt]
    			Futr: csv-import %Futures.txt
    		]
}

    		CsvFilePath: to-file join "./NSEFO/fo" [Sd "bhav.csv"]         ;Create string to read csv file - precede with date
   
    		Quotes: csv-import  CsvFilePath					; Import csv file into block
    		remove  Quotes 							; Delete first line of Quotes

    		either Futures/data  [ 							; If futures data required  	
    			if not exists? %Futures.txt [write %Futures.txt]
    			Futr: csv-import %Futures.txt
    		]
    		[	; else
    			foreach line Quotes 									
    			[ if  any [(find/part line/1 "FUT" 3) (line/11 = "0" )] [clear line]] ; delete futures as well as 0 volume
    		]										
    		
    		either NseOpt/data  [ 							; If Option data required  		
    			foreach line Quotes [ if  line/11 = "0"  [clear line]]] [ ; Delete lines with 0 volume.	 
    			foreach line Quotes 									; else
    				[ if  any [(find/part line/1 "OPT" 3) (line/11 = "0" )] [clear line]] ; delete option as well as 0 volume
    		]										
   		remove-each line Quotes [empty? line]
 
   		foreach line Quotes [ quote: copy line
  				parse quote/3 [3 skip copy mon to "-" 3 skip copy year to end] 
   				expiry: join year [mon]
   			either find/part line/1 "OPT" 3 [		  	; If Option data required
   				line/1: join quote/2 [ expiry  quote/4  quote/5]] [ ; write Symbol +  Expiry date + Strike + Option Type in first place
 				either Futures/data [
 					foreach mon Futr [
 						either mon/1 = quote/3 [line/1: join quote/2 [mon/2] break][
 								line/1: join quote/2 [ expiry]
 						]
 					]
 				][
 					line/1: join quote/2 [ expiry] 			; else write Symbol and Expiry date in first place
 				]
 			]
     			Temp2:  form-date (to-date Date) "%Y%m%d"		; Pick timestamp from quote and Change date format
    			line/2: copy Temp2 					; write date in second place
    			line/3: copy quote/6 					; O
    			line/4: copy quote/7					; H
    			line/5: copy quote/8 					; L
    			line/6: copy quote/9 					; C
    			line/7: copy quote/11 					; CONTRACTS (volume)
    			line/8: copy quote/13 ;line/13				; OI
    			foreach item line [change item append item ","]			; append comma to each field
    			head line						;move to beginning of line
    			line: skip line 7						; move to volume in line
   			clear next line							; Remove everything after Volume
    			append line newline 						; append carrige return to line
    			]

    		if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]
    		write/append Target Quotes
		if verbose/data [append Log/text "Created NSE-FO.txt file^/^/" scroll-text Log]
		delete CsvFilePath								;Delete CSV file		
		if not Nsed/data [delete to-file rejoin ["./NSEFO/fo" Sd "bhav.csv.zip" ]	; Delete bhavcopy zip if not required
			if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log]
		]	
	]
]
    		
downloadNseCur: func [Date] [
   		Target: to-file join "./NSECUR/" [DateYmd "NSE-CF.txt"]
		date2: uppercase form-date Date "%d%m%Y"

	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			;Prepare Currency URL and download file to disk in ./NSECUR folder
			;URL format - https://www1.nseindia.com/archives/cd/bhav/CD_Bhavcopy130120.zip
			NseCur_Url: rejoin ["curl -f -k --max-time 10  --url " "https://www1.nseindia.com/archives/cd/mkt_act/cd" 
				date2  ".zip"] 		; format NSE Currency Bhavcopy url
			NseCur_Url: rejoin [NseCur_Url " -o /ABCD/NSECUR/cd" date2 ".zip"]
			write/append %log.txt NseCur_Url

			either zero? call/wait NseCur_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join NseCur_Url "^/Downloaded NSE Currency Bhavcopy ^/" scroll-text Log]
				]
				[	write/append %log.txt rejoin [NseCur_Url "^/  NSE Currency bhavcopy not found ^/"]
					append Log/text join NseCur_Url "^/Server made a boo boo ...... NSE Currency bhavcopy not found ^/^/" scroll-text Log 
					Exit  
				]
		]
		
		ZipFilePath:  join "unzip -o ./NSECUR/cd" [ date2 ".zip" " -d ./NSECUR -i cf" date2 ".csv"]		;Create string to call unzip command
		err: copy ""
		either zero? call/wait/error ZipFilePath err [						;extract bhavcopy csv file from zip file
		     if verbose/data [append Log/text "Extracted cdBhavcopy^/" scroll-text Log]
		] [	either err = "caution: filename not matched:  -i^/" [
				append Log/text "Extracted cdBhavcopy^/" scroll-text Log
			][
			write/append %log.txt rejoin ["Bad zip file -./NSECUR/cd" Date2 ".zip"]
			append Log/text "Bad zip file.. could not extract cdBhavcopy^/^/" show log
			if verbose/data [append Log/text join ZipFilePath ["^/"] scroll-text log]
			Exit
			]
		]
  		if Futures/data [
    			if not exists? %Futures.txt [write %Futures.txt]
    			Futr: csv-import %Futures.txt
    		]

;	   	Current format of quotes in foBhavcopy csv file :  
;		INSTRUMENT, SYMBOL, EXP_DATE ,OPEN_PRICE ,HI_PRICE ,LO_PRICE ,CLOSE_PRICE, OPEN_INT* ,TRD_VAL ,TRD_QTY ,NO_OF_CONT ,NO_OF_TRADE     

    		CsvFilePath: to-file join "./NSECUR/cf" [(form-date Date "%d%m%Y") ".csv"]         ;Create string to read csv file - precede with date
   
    		Quotes: csv-import  CsvFilePath					; Import csv file into block
    		remove  Quotes 							; Delete first line of Quotes
    		
   		foreach line Quotes [ if  find line/1 "IRC"  [clear line]]	;
   		;tail Quotes back Quotes remove Quotes					;
  		remove-each line Quotes [(empty? line) or (not line/2 )]
  		
  		foreach line Quotes [ quote: copy line 
  			either error? try [
 				either Futures/data [
 					foreach mon Futr [
 						either mon/1 = quote/3 [line/1: join quote/2 [mon/2] break][
							line/1: trim/all join quote/2 [ "_" quote/3] 	; write Symbol and Expiry date in first place	
 						]
 					]
 				][
  			       line/1: trim/all join quote/2 [ "_" quote/3] 	; write Symbol and Expiry date in first place	
 				]

  			       Temp2:  form-date  Date "%Y%m%d"		; Pick timestamp from quote and Change date format
  			       line/2: copy Temp2 				; write date in second place
  			       line/3: copy quote/4 				; O
  			       line/4: copy quote/5				; H
  			       line/5: copy quote/7 				; L
  			       line/6: copy quote/7 				; C
  			       line/7: copy quote/10 				; CONTRACTS (volume)
  			       line/8: copy quote/8				; OI 
  			    ] [
  			        write/append %log.txt join "line - " [ line/1]
  			    ][  
  			        foreach item line [change item append item ","]			; append comma to each field
  			        head line						;move to beginning of line
  			        line: skip line 7						; move to volume in line
  			        clear next line							; Remove everything after Volume
  			        append line newline 						; append carrige return to line
  			    ]
    		]

		if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]		
    		write/append Target Quotes
		if verbose/data [append Log/text "Created NSE-CF.txt file^/^/" scroll-text Log]
		delete CsvFilePath								;Delete CSV file
 			 if not Nsed/data [delete to-file rejoin ["./NSECUR/cd" Date2 ".zip" ]	; Delete bhavcopy zip if not required
			    if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log ]
			 ]	
	]
]


;Download NSE Index data
;NSE Index URL as given by TRavi -   
;https://archives.nseindia.com/content/indices/ind_close_all_ddmmYYYY.csv

downloadNsei: func [Date][
    	Target: to-file join "./NSE/" [DateYmd "NSE-NDX.txt"]
    	Date2: form-date Date "%d%m%Y"						;new format of date from 01-12-2015
   		CsvFilePath: to-file join "./NSE/ind_close_all_" [Date2 ".csv"]         ;Create string to read csv file - precede with date

	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			;  New code Start	
			; New URL from 1-12-2015 www.nseindia.com/content/indices/ind_close_all_01122015.csv for All Indices 
			;NSE Index URL as given by TRavi -   
			;https://archives.nseindia.com/content/indices/ind_close_all_ddmmYYYY.csv

			Indices_Url:  to-url join "https://archives.nseindia.com/content/indices/ind_close_all_" [ Date2 ".csv"]
			Indices_Url: rejoin ["curl -f -k --max-time 10  --url " Indices_Url " -o /ABCD/NSE/ind_close_all_"  Date2 ".csv"]

			either zero? call/wait Indices_Url  			; download index file using curl
				[	if verbose/data [append Log/text join Indices_Url "^/Downloaded index file^/" scroll-text Log]
					;break 
				]
				[	write/append %log.txt rejoin [Indices_Url "^/  index file not found " DateYmd "^/"]
					append Log/text join Indices_Url "^/Server made a boo boo ...... index file not found- ^/ try manually^/^/" scroll-text Log 
					Exit  
				]
		]
		; Start processing downloaded file
 		Indices: csv-import  CsvFilePath
    		remove Indices							;Remove first line of Indices
    		
		selected: csv-import %NSEINDICES.txt 
		d: []
		
    		if NseiS/data [
    			if not exists? %NSEINDICES.txt [write %NSEINDICES.txt]
    			foreach item selected [append/only d item/1]
    			foreach line Indices [ if  not find d line/1  [clear line]]	;
    			remove-each line Indices [empty? line]
    		]
    		
    		if renameIdx/data [
    			foreach line indices [ foreach item selected [if all [item/1 = line/1 item/2 <> none ]  [line/1: copy item/2]]]
    		]
		; This is current format of index file from 01-12-2015 
		; Index Name,Index Date,Open Index Value,High Index Value,Low Index Value,Closing Index Value,Points Change,Change(%),Volume,Turnover (Rs. Cr.),P/E,P/B,Div Yield
    			
    			
    		foreach index Indices [						;Format each line of Indices
    			Temp2: form-date (to-date index/2) "%Y%m%d"		; Pick date from quote and Change date format
			index/2: copy Temp2
    			index/7: copy index/9 					; Replace "Points Change" by "Volume" 
    			head index
    			clear  skip index 7					; Delete all items after Volume
    			foreach item index [ append  item ","]			; Append comma to all fields
	    		append  Index newline					; Append index line and carriage return to Quotes
    		]

    		if not Nsed/data [delete CsvFilePath ]				; Delete Index file if not required
    		if headers/data [write Target "Index Name,Index Date,Open Index Value,High Index Value,Low Index Value,Closing Index Value,Volume^/"]
    		write/append Target Indices
		if verbose/data [append Log/text "Created NSE-NDX.txt data file^/^/" scroll-text Log]
	]
]



; format of BSE Bhavcopy url https://www.bseindia.com/download/BhavCopy/Equity/EQ181218_CSV.ZIP
downloadBseBhav: func [Date] [		
  		Target: to-file join "./BSE/" [DateYmd "BSE-EQ.txt"]
	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			BSE_Url: rejoin ["https://www.bseindia.com/download/BhavCopy/Equity/EQ" 
				(uppercase form-date Date "%d%m%y")  "_CSV.zip"] 		
			BSE_Url: rejoin ["curl -o /ABCD/BSE/EQ"  (uppercase form-date Date "%d%m%y")  "_CSV.zip "  BSE_Url]
		
			either zero? call/wait BSE_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join BSE_Url "^/Downloaded BseBhavcopy Zip^/" scroll-text Log]
					;break 
				]
				[	write/append %log.txt rejoin [BSE_Url "^/BSE/EQUITIES/bhavcopy not found " DateYmd "^/"]
					append Log/text join BSE_Url "^/Server made a boo boo ...... BSE Bhavcopy not found-error^/^/" scroll-text Log 
					Exit  
				]
		]

		;start processing downloaded file
		;write/binary to-file rejoin ["./BSE/" Sd "bhav.csv.zip"] BB		; write variable to disk in ./BSE folder
		ZipFilePath:  join "unzip -od ./BSE/  ./BSE/EQ" [ (uppercase form-date Date "%d%m%y")  "_CSV.zip" " EQ" (uppercase form-date Date "%d%m%y") ".CSV"]		;Create string to call unzip command
		
		either zero? call/wait ZipFilePath 						;extract bhavcopy csv file from zip file
			[	if verbose/data [append Log/text "Extracted BSE Bhavcopy^/" scroll-text Log]]
			[	write/append %log.txt rejoin ["Bad Zip file - ./BSE/" Sd "bhav.csv.zip"]
				append Log/text "Bad zip file.. could not extract BSE Bhavcopy^/" show log
				;append Log/text join ZipFilePath ["^/^/"] show log
				Exit		
		]
		
;	   	Current format of quotes in BSE Bhavcopy csv file :  
;		SC_CODE,SC_NAME,SC_GROUP,SC_TYPE,OPEN,HIGH,LOW,CLOSE,LAST,PREVCLOSE,NO_TRADES,NO_OF_SHRS,NET_TURNOV,TDCLOINDI     

    		CsvFilePath: to-file join "./BSE/EQ" [(form-date Date "%d%m%y") ".CSV"]         ;Create string to read csv file - precede with date
   
    		Quotes: csv-import  CsvFilePath					; Import csv file into block
    		remove  Quotes 							; Delete first line of Quotes
    		foreach line Quotes [ if  not find line/4 "Q"  [clear line]]			; Delete all quotes othet tha SC_type "Q"
    		remove-each line Quotes [empty? line]
	  		
    		foreach line Quotes [ 
  		quote: copy line 
  		either error? try [
  	           ;line/1: copy quote/2 					; write Symbol and Expiry date in first place	
  	           Temp2:  form-date  Date "%Y%m%d"				; Pick timestamp from quote and Change date format
  	           line/2: copy Temp2 						; write date in second place
  	           line/3: copy quote/5 					; O
  	           line/4: copy quote/6						; H
  	           line/5: copy quote/7 					; L
  	           line/6: copy quote/8 					; C
  	           line/7: copy quote/12 					; CONTRACTS (volume)
  	           line/8: copy quote/2						; Scrip Name preserved 
  	    	] [
  	        write/append %log.txt join "line - " [ line]
  	        ][  
  	        foreach item line [change item append item ","]			; append comma to each field
  	        head line							;move to beginning of line
  	        line: skip line 7						; move to volume in line
  	        clear next line							; Remove everything after Volume
  	        append line newline 						; append carrige return to line
  	    ]
    	]

		if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]
   		write Target Quotes
		if verbose/data [append Log/text "Created BSE-EQ.txt file^/^/" scroll-text Log]
		delete CsvFilePath								;Delete CSV file
		if not Nsed/data [delete to-file rejoin ["./BSE/EQ" (uppercase form-date Date "%d%m%y")  "_CSV.zip" ]	; Delete bhavcopy zip if not required
			if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log]
		]
	]
]

 ;format of BSE Derivative url https://www.bseindia.com/download/Bhavcopy/Derivative/bhavcopy27-11-18.zip
downloadBseDer: func [Date] [
   		Target: to-file join "./BSEFO/bhavcopy" [(form-date Date "%d-%m-%y") ".xls"]
	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			BseDer_Url: rejoin ["curl -o /ABCD/BSEFO/fo" Sd  "bhav.csv.zip " "https://www.bseindia.com/download/Bhavcopy/Derivative/bhavcopy" 
				(uppercase form-date Date "%d-%m-%y")  ".zip"] 		
			
			if not zero? call/wait BseDer_Url  [			; download Derivative bhavcopy zip file using curl
				write/append %log.txt rejoin ["BSE/Futures/bhavcopy not found " DateYmd "^/"]
				append Log/text  "Server made a boo boo ...... BSE fo Bhavcopy not found-error^/^/" scroll-text Log 
				Exit  
			  	]
			  	[if verbose/data [
			  		append Log/text "Downloaded Bse fo Bhavcopy Zip^/" scroll-text Log 
			  		]
			  		break
			  	]
		]
	
;		write/binary to-file rejoin ["./BSEFO/fo" Sd "bhav.csv.zip"] BD		; write variable BD to disk in ./BSEFO folder
		ZipFilePath:  join "unzip -od ./BSEFO  ./BSEFO/fo" [ Sd "bhav.csv.zip" ]		;Create string to call unzip command
		
		either zero? code: call/wait ZipFilePath [						;extract bhavcopy csv file from zip file
			if verbose/data [append Log/text "Extracted BSE fo Bhavcopy^/" scroll-text Log]
			
			if not Nsed/data [delete to-file rejoin ["./BSEFO/fo" Sd "bhav.csv.zip" ]	; Delete bhavcopy zip if not required
				if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log]
			]	
			] [	append Log/text "Bad zip file.. could not extract BSE fo Bhavcopy^/" show log
				write/append %log.txt code
				append Log/text join ZipFilePath ["^/^/"	] show log
				Exit
		]
	]
	
]

; format of BSE Currency https://www.bseindia.com/bsedata/CIML_bhavcopy/CurrencyBhavCopy_20140627.ZIP
downloadBseCur: func [Date] [
   	Target: to-file join "./BSECUR/" [DateYmd "BSE-CU.txt"]
	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			BseCur_Url:  rejoin [ "curl -o /ABCD/BSECUR/Cu"  Sd "bhav.csv.zip " "https://www.bseindia.com/bsedata/CIML_bhavcopy/CurrencyBhavCopy_" 
				(uppercase form-date Date "%Y%m%d")  ".zip"] 		
			if not zero? call/wait BseCur_Url  [			; download bhavcopy zip file using curl
				write/append %log.txt rejoin ["BSE/Currency/bhavcopy not found " DateYmd "^/"]
				append Log/text  "Server made a boo boo ...... BSE Cu Bhavcopy not found-error^/^/" scroll-text Log 
				Exit
			]
			[	if verbose/data [
					append Log/text "Downloaded Bse Cu Bhavcopy Zip^/" scroll-text Log 
				]
				break
			]
		]
		;Start Processing downloaded file
		ZipFilePath:  join "unzip -od ./BSECUR/  ./BSECUR/Cu" [ Sd "bhav.csv.zip" ]		;Create string to call unzip command
		
		either zero? code: call/wait ZipFilePath [						;extract bhavcopy csv file from zip file
			if verbose/data [append Log/text "Extracted BSE Cu Bhavcopy^/" scroll-text Log]
			] [	append Log/text "Bad zip file.. could not extract BSE Cu Bhavcopy^/" show log
				write/append %log.txt code
				append Log/text join ZipFilePath["^/^/"] show log
				Exit
		]
				
;	   	Current format of quotes in BSE Bhavcopy csv file :  
;		CONTRACT TYPE,SYMBOL,EXPIRY,STRIKE,OPTION TYPE,OPEN,HIGH,LOW,CLOSE,L T DATE,WT. AVG. PRICE,PREM/DISC,PREM/DISC(%),CONTRACTS_TRADED,TURNOVER (RS.LAKHS),OPEN     

    	CsvFilePath: to-file join "./BSECUR/CurrencyBhavCopy_" [(form-date Date "%Y%m%d") ".CSV"]         ;Create string to read csv file - precede with date
   
    	Quotes: csv-import  CsvFilePath					; Import csv file into block
    	remove  Quotes 					1	; Delete first line of Quotes
    	
   	foreach line Quotes [ if  not find line/1 "FUTCUR"  [clear line]]			; Delete all quotes othet tha SC_type "Q"
  	remove-each line Quotes [empty? line]
  		
  	foreach line Quotes [ quote: copy line 
  	    either error? try [
  	           line/1: copy join quote/2 ["_" quote/3]		 	; write Symbol and Expiry date in first place	
  	           Temp2:  form-date  Date "%Y%m%d"				; Pick timestamp from quote and Change date format
  	           line/2: copy Temp2 						; write date in second place
  	           line/3: copy quote/6 					; O
  	           line/4: copy quote/7						; H
  	           line/5: copy quote/8 					; L
  	           line/6: copy quote/9 					; C
  	           line/7: copy quote/14 					; CONTRACTS (volume)
  	           line/8: copy quote/16					; OI 
  	    ] [  
  		   write/append %log.txt join "line - " [ line]
  	    ] [  
  		   foreach item line [change item append item ","]			; append comma to each field
  		   head line						;move to beginning of line
  		   line: skip line 7						; move to volume in line
  		   clear next line							; Remove everything after Volume
  		   append line newline 						; append carrige return to line
  	     ]
    	]

	if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]
	write Target Quotes 
	if verbose/data [append Log/text "Created BSE-CU.txt file^/^/" scroll-text Log]
	delete CsvFilePath								;Delete CSV file
			if not Nsed/data [delete to-file rejoin ["./BSECUR/Cu" Sd "bhav.csv.zip" ]	; Delete bhavcopy zip if not required
				if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log]
			]	
	]
]


; format of Amfi MFunds NAV url for last available day - https://www.amfiindia.com/spages/NAVOpen.txt
downloadAmfiL: func [Date] [		
	DateYmd:  form-date Date "%Y-%m-%d"				;format date to YYYY-mm-dd for Target file
	Target: to-file join "./AmfiMF/" [DateYmd "MF.txt"]

	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			Amfi_Url: "https://www.amfiindia.com/spages/NAVOpen.txt" 
			Amfi_Url: rejoin ["curl " Amfi_Url " -o /ABCD/AmfiMF/"  DateYmd "MF.txt"]

			either zero? call/wait Amfi_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join Amfi_Url "^/Downloaded Amfi Last NAV File^/" scroll-text Log]
					;break 
				]
				[	write/append %log.txt rejoin [Amfi_Url "Amfi NAV file not found " DateYmd "^/"]
					append Log/text join Amfi_Url "^/Server made a boo boo ...... Amfi NAV file not found-error^/^/" scroll-text Log 
					Exit  
				]
		]
		;start processing downloaded file
			CsvFilePath: to-file rejoin ["./AmfiMF/" DateYmd "MF.txt"]         ;Create string to read csv file - precede with date
   
    		Quotes: mf-import  CsvFilePath					; Import csv file into block
    		Heading: "Scheme Code,Date in YYYYMMDD format,NAV,NAV,NAV,NAV,Scheme Name"
    		remove  Quotes 							; Delete first line of Quotes
    		remove-each line Quotes [line/1 = " "]
    		foreach line Quotes [ either not error? try [to-integer line/1][][clear line]]
    		remove-each line Quotes [empty? line]

;		The Current Format is Scheme Code;ISIN Div Payout/ ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date
;		The desired format is Scheme Code,Date in YYYYMMDD format,-,-,-,Net Asset Value,-

	  	foreach line Quotes [ 
	  		quote: copy line 
	  		either error? try [
  	           Temp2:  form-date to-date quote/6 "%Y%m%d"				; Pick timestamp from quote and Change date format
  	           line/2: copy Temp2 						; write date in second place
  	           line/3: copy quote/5	 					; O
  	           line/4: copy quote/5						; H
  	           line/6: copy quote/5 					; C
  	           append line quote/4 					; write Scheme name in seventh place
;  	           print line
  	    ] [  
  		   write/append %log.txt rejoin ["line - "  line newline]
  	    ] [
  		   foreach item line [change item append item ","]			; append comma to each field
  		  	 head line						;move to beginning of line
  		  	 line: skip line 7						; move to Close in line
  		  	 clear next line							; Remove everything after Volume
  		  	 append line newline 						; append carrige return to line
    		]
    	]
		if headers/data [write Target join Heading "^/"]
   		write Target Quotes
		if verbose/data [append Log/text "Created MF.txt file^/^/" scroll-text Log]

	]
]




; format of Amfi MFunds Historical NAV url http://portal.amfiindia.com/DownloadNAVHistoryReport_Po.aspx?mf=3&tp=1&frmdt=14-Nov-2018&todt=14-Nov-2018
downloadAmfiH: func [Sdt Edt] [	
	Sdt: form-date Sdt "%d-%b-%Y"
	Edt: form-date Edt "%d-%b-%Y"
;	DateYmd:  form-date Date "%Y-%m-%d"				;format date to YYYY-mm-dd for Target file
	if not exists? %MF_Numbers.txt [
		Temp: ["3,Aditya Birla Sun Life Mutual Fund^/" "4,Baroda Mutual Fund^/" "6,DSP Mutual Fund^/" "9,HDFC Mutual Fund"]
				write %MF_Numbers.txt Temp
				Alert {MF_Numbers.Txt file not found. ..         . Created Sample file for 5 MF numbers.               Read it and create your own}
				Alert {Use this URL - http://portal.amfiindia.com/DownloadNAVHistoryReport_Po.aspx?mf=3&tp=1&frmdt=14-Nov-2018&todt=14-Nov-2018^/
				Replace mf=3 with your number and find out}
    ]
	selected: csv-import %MF_Numbers.txt 
	foreach item selected [
		Target: to-file rejoin ["./AmfiMF/" Sdt " to " Edt "-" item "-O.txt"]

		catch [

			either exists? Target [
				if not Onlyfiles/data [
					if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	continue
				]
			] [	
					append Log/text rejoin ["Downloading MF - " item "^/"] scroll-text Log
					Amfi_Url: to-url rejoin ["http://portal.amfiindia.com/DownloadNAVHistoryReport_Po.aspx?mf=" item/1 "&tp=1&frmdt=" Sdt "&todt=" Edt] 
					mfdata: read Amfi_Url
					write/append Target mfdata
					mfdata: copy []
			]
			;start processing downloaded file

			Quotes: mf-import  Target					; Import csv file into block
			CsvFilePath: to-file rejoin ["./AmfiMF/" Sdt " to " Edt "-" item ".txt"]        ;Create string to read csv file - precede with date

			if not empty? Quotes [
				if not Onlyfiles/data [
	   				if verbose/data [append Log/text join Amfi_Url "^/Downloaded Amfi historical NAV File^/" scroll-text Log
					;break 
					]
				]
				[	write/append %log.txt rejoin [Amfi_Url "Amfi NAV file not found " DateYmd "^/"]
					append Log/text join Amfi_Url "^/Server made a boo boo ...... Amfi NAV file not found-error^/^/" scroll-text Log 
					Exit  
				]
			]
			if not NSED/data [delete Target]
		
;	   	Current format of quotes in Amfi NAV csv file :  
;		Scheme Code;Scheme Name;ISIN Div Payout/ISIN Growth;ISIN Div Reinvestment;Net Asset Value;Repurchase Price;Sale Price;Date
;		The desired format is-
;		Scheme Code,Date in YYYYMMDD format,ISIN Div Payout/ISIN Growth,ISIN Div Reinvestment,Repurchase Price,Net Asset Value,Sale Price,Scheme Name
				
    		Heading: "Scheme Code,Date,ISIN Div Payout/ISIN Growth,ISIN Div Reinvestment,Net Asset Value,Repurchase Price,Sale Price,Scheme Name^/"
    		remove-each line Quotes [line/1 = " "]
    		foreach line Quotes [ either not error? try [to-integer line/1][][clear line]]
    		remove-each line Quotes [empty? line]
    		    		
    		foreach line Quotes [ 
    			quote: copy line 
    			either error? try [
    				Temp2:  form-date to-date quote/8 "%Y%m%d"				; Pick timestamp from quote and Change date format
    				line/2: copy Temp2 						; write date in second place
    				line/8: quote/2 						; write Scheme name in seventh place
;		  	        print line
				] [  
					write/append %log.txt rejoin ["line - "  line newline]
				] [
    			foreach item line [change item append item ","]			; append comma to each field
    			append line newline 						; append carrige return to line
    			]
    		]
    		if headers/data [write CsvFilePath Heading]
    		write/append CsvFilePath Quotes
    		Quotes: copy[]
    		if verbose/data [append Log/text "Created MF.txt file^/^/" scroll-text Log]
    	]
	]
]


downloadNseIRF: func [Date] [		write/append %log.txt "Downloading IRFBhavcopy" scroll-text Log 
   		Target: to-file join "./NSEIRF/" [DateYmd "NSE-IRF.txt"]
		date2: uppercase form-date Date "%d%m%Y"

	either exists? Target [if verbose/data [append Log/text join Target [" File already exists^/^/"] show log]	Exit] [

		if not Onlyfiles/data [
			;Prepare Interest Rate Futures URL and download file to disk in ./NSEIRF folder
			
			NSEIRF_Url: rejoin ["curl -f -k --max-time 10  --url " https://archives.nseindia.com/archives/ird/bhav/IRF_Bhavcopy (form-date Date "%d%m%y")  ".zip"] 	; format NSE Interest Rate Futures Bhavcopy url
			NSEIRF_Url: rejoin [NseIRF_Url " -o /ABCD/NSEIRF/IRF_Bhavcopy" (form-date Date "%d%m%y")  ".zip"]
			write/append %log.txt NSEIRF_Url

			either zero? call/wait NSEIRF_Url  			; download bhavcopy zip file using curl
				[	if verbose/data [append Log/text join NseIRF_Url "^/Downloaded NSE IRF Bhavcopy ^/" scroll-text Log]
				]
				[	write/append %log.txt rejoin [NSEIRF_Url "^/  NSE IRF bhavcopy not found ^/"]
					append Log/text join NSEIRF_Url "^/Server made a boo boo ...... NSE IRF bhavcopy not found ^/^/" scroll-text Log 
					Exit  
				]
		]
		
		ZipFilePath:   join "unzip -o  ./NSEIRF/IRF_Bhavcopy"[(form-date Date "%d%m%y")  ".zip"" -d ./NSEIRF/ -i IRF_NSE"form-date Date "%d%m%y" ".csv" ]	;Create string to call unzip command
		err: copy ""
		either zero? call/wait/error ZipFilePath err [						;extract bhavcopy csv file from zip file
		     if verbose/data [append Log/text "Extracted IRFBhavcopy^/" scroll-text Log]
		] [	either err = "caution: filename not matched:  -i^/" [
				append Log/text "Extracted IRFBhavcopy^/" scroll-text Log
			][
			write/append %log.txt rejoin ["Bad zip file -./NSEIRF/IRF_Bhavcopy" form-date Date "%d%m%y" ".zip"]
			append Log/text "Bad zip file.. could not extract IRFBhavcopy^/^/" show log
			if verbose/data [append Log/text join ZipFilePath ["^/"] scroll-text log]
			Exit
			]
		]

;	   	Current format of quotes in IRFBhavcopy csv file :  
;		CONTRACT_D, PREVIOUS_S, OPEN_PRICE,  ,HIGH_PRICE ,LOW_PRICE ,CLOSE_PRICE, SETTLEMENT, NET CHANGE, OI_NO_CON ,TRADED_QUA ,TRD_NO_CONTRACTS ,TRADED_VAL     
		if Futures/data [
    			if not exists? %Futures.txt [write %Futures.txt]
    			Futr: csv-import %Futures.txt
    		]
    		CsvFilePath: to-file join "./NSEIRF/IRF_NSE"[(form-date Date "%d%m%y") ".csv"]         ;Create string to read csv file - precede with date
			
   
    		Quotes: csv-import  CsvFilePath					; Import csv file into block
    		remove  Quotes 							; Delete first line of Quotes
			either NseOpt/data  [ 							; If Option data required 
			foreach line Quotes [ if  line/11 = "0"  [clear line]]] [ ; Delete lines with 0 volume.	 
    			foreach line Quotes 									; else
    				[ if  any [(find/part line/1 "OPT" 3) (line/11 = "0" )] [clear line]] ; delete option as well as 0 volume
    		]
   		
   		;tail Quotes back Quotes remove Quotes					;
  		remove-each line Quotes [(empty? line)]
  		
  		foreach line Quotes [ quote: copy line 
  			either error? try [
  			       Temp2:  form-date  Date "%Y%m%d"		; Pick timestamp from quote and Change date format
  			       line/2: copy Temp2 				; write date in second place
  			       line/7: copy quote/10 				; CONTRACTS (volume)
  			       line/8: copy quote/9				; OI 
  			    ] [
  			        write/append %log.txt join "line - " [ line]
  			    ][  
  			        foreach item line [change item append item ","]			; append comma to each field
  			        head line						;move to beginning of line
  			        line: skip line 8						; move to OI in line
  			        clear next line							; Remove everything after OI
  			        append line newline 						; append carrige return to line
  			    ]
    		]

		if headers/data [write Target "SYMBOL,DATE,OPEN,HIGH,LOW,CLOSE,VOLUME,OI^/"]		
    		write Target Quotes
		if verbose/data [append Log/text "Created NSE-IRF.txt file^/^/" scroll-text Log]
		delete CsvFilePath								;Delete CSV file
 			 if not Nsed/data [delete to-file rejoin ["./NSEIRF/IRF_Bhavcopy" (uppercase form-date Date "%d%m%y") ".zip" ]	; Delete bhavcopy zip if not required
			    if verbose/data [append Log/text "Deleted zip file^/^/" scroll-text Log ]
			 ]	
	]
]


download: func ["Downloads all bhavcopies and extracts csv from it." Sdt Edt] [
	if exists? %log.txt [delete %log.txt]

	if any [Nsebhav/data NseDer/data NseOpt/data NseCur/data Nsei/data NseIRF/data Bsebhav/data BseDer/data BseCur/data]	[
	    for Date Sdt Edt 1 [													;increment date 1 day upto end date
	    	catch [
	    		Sd: uppercase form-date Date "%d%b%Y" 			;format date to ddMMMYYYY for download 
	    		DateYmd:  form-date Date "%Y-%m-%d"				;format date to YYYY-mm-dd for Target file
		    	    
	    		if Weekends/data [if  Date/weekday > 5 [append Log/text join DateYmd [" is weekend^/^/"] continue ]] ;

	    		append Log/text join "^/ *** Downloading for " [ DateYmd "*** ^/^/"] scroll-text Log ;

	    		if Nsebhav/data	[downloadNseBhav Date]			; If NSE Bhav is checked download NSE Bhavcopy.	
	    		if any [NseDer/data NseOpt/data]	[downloadNseDer Date]	; If NSE Derivatives is checked download NSE Futures.
	    		if NseCur/data	[downloadNseCur Date]			; If NSE Currency is checked download NSE Currency.
	    		if Nsei/data	[downloadNsei Date]				; If NSE Index is checked download NSE Indices.
	    		if NseIRF/data	[downloadNseIRF Date]				; If NseIRF is checked download NSE Interest Rate Futures.
	    		if Bsebhav/data	[downloadBseBhav Date]			; If BSE Bhav is checked download BSE Bhavcopy.	
	    		if BseDer/data	[downloadBseDer Date]			; If BSE Futures is checked download BSE Futures.	
	    		if BseCur/data	[downloadBseCur Date]			; If BSE Currency is checked download BSE Currency.
	    	]
		]	
	]

	if AmfiL/data	[downloadAmfiL Edt]					; If AmfiL is checked download Amfi Current Day .			
	if AmfiH/data [downloadAmfiH Sdt Edt]					; If AmfiH is checked download Amfi Historical data.
	
	append Log/text "^/****** Download complete****** ^/" scroll-text Log
	append Log/text "^/See log.txt in installation folder /ABCD ^/  for errors if any stated above " scroll-text Log 
]

Changesetting: func [num] [setting: pick settings num
		either setting = "yes" [poke settings num "no" ] [poke settings num "yes" ]
		writesettings
]


NSE: layout [
	across	
	btn "Start Date" [ 
		if Std: request-date [Sdate/text: ToDMY Std show Sdate]  ; Update the Start-date text field: ;system/view/vid/req-funcs/req-date/init
	]
	Sdate: field 80x22 ToDMY Std [if error? try [to-date Sdate/text] [
		Alert "Input date in proper format^/ dd/mm/yy or dd/mm/yyyy or ^/ dd-mm-yy or dd-mm-yyyy" 
		Sdate/text: ToDMY Std show Sdate]]
	
	btn "End Date" [
		if Ed: request-date [	Edate/text: ToDMY Ed show Edate]	; Update the End-date text field: ;		system/view/vid/req-funcs/req-date/init
	]
   	Edate: field 80x22 ToDMY Ed [if error? try [to-date Edate/text] [
		Alert "Input date in proper format^/ dd/mm/yy or dd/mm/yyyy or ^/ dd-mm-yy or dd-mm-yyyy" 
		Edate/text: ToDMY Ed show Edate]]
;	tab btn "Help" bold Green 80x22 [view/new layout [area  1000x700 read %README-ABCD.txt] ]
	tab btn "Help" bold Green 80x22 [call   "readme-abcd.doc" ]
	below across
	text bold black "Process Downloaded files only -" Onlyfiles: Check either settings/19 = "yes" [true][false]	[Changesetting 19]
	below across 
	text bold black "NSE-" 
	text "Equity" NseBhav: Check either settings/1 = "yes" [true][false]	[Changesetting 1]
	text "Equity+OI" Oi: check  either settings/2 = "yes" [true][false]		[Changesetting 2] 
	text "Futures" NseDer: check either settings/3 = "yes" [true][false]	[Changesetting 3] 
	text "Fut + Opt" NseOpt: check either settings/4 = "yes" [true][false]	[Changesetting 4] 
	text "Currency" NseCur: check either settings/5 = "yes" [true][false] 	[Changesetting 5]
		return 
		indent 40
	text "Indices"   Nsei: check either settings/6 = "yes" [true][false] 	[Changesetting 6]
	text "Selected?"   NseiS: check  either settings/7 = "yes" [true][false][Changesetting 7] 
		pad 10
	text "Interest Rate Futures" NseIRF: check either settings/20 = "yes" [true][false] [Changesetting 20]
		return
	text bold black "Rename -" pad 10 
	text "Futures?" Futures: check  either settings/8 = "yes" [true][false] [Changesetting 8]
	text "Indices?" renameIdx: check either settings/9 = "yes" [true][false][Changesetting 9]
		return
		
	text bold black "BSE-" 
	text "Equity" 	BseBhav: check either settings/10 = "yes" [true][false]	[Changesetting 10]
	text "Futures" 	BseDer: check either settings/11 = "yes" [true][false] 	[Changesetting 11]
	text "Currency" BseCur: check either settings/12 = "yes" [true][false]	[Changesetting 12]
		Return
	text bold black "AMFI" 
	text "Last" 	AmfiL: check either settings/13 = "yes" [true][false]	[Changesetting 13]
	text "Historic *** download upto 4 years or one AMC at a time" Bold Red AmfiH: check either settings/14 = "yes" [true][false][Changesetting 14]
		return
	text "Preserve Original files?" bold black  Nsed: check either settings/15 = "yes" [true][false] [Changesetting 15]
	text "Verbose" verbose: check either settings/16 ="yes" [true] [false] 	[Changesetting 16]
	text "SkipWeekends?" Weekends: check either settings/17 ="yes" [true] [false] [Changesetting 17]
	return
	text "Headers Required?" headers: check either settings/18 ="yes" [true] [false] [Changesetting 18]
	
	tab tab
	btn "Download" bold Green 80x22 [ if validate-screen [download to-date Sdate/text to-date Edate/text]] pad 10
	btn "Exit" bold Red 80x22[ Quit]  return
	text "Log" return
	Log: area 450x350  wrap settings; [scroll-text Log]
	sldr: slider 16x350 [scroll-para Log sldr]
]

view NSE
