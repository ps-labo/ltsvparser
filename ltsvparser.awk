#!/usr/bin/awk -f
#
# ltsvparser.awk
# ltsv ログのパーサーフィルタ
#
# ・ltsv から json に変換できます。
#   ltsvparser.awk [ログファイル]
#
# ・ltsv のログから特定のラベルを抜き出せます。
#   ltsvparser.awk label=datetime,speed_download [ログファイル]
#
# ・さらに、出力結果を tsv や ltsv にもできます。
#   ltsvparser.awk label=datetime,speed_download format=ltsv [ログファイル]
#   ltsvparser.awk label=datetime,speed_download format=tsv [ログファイル]
#
# ・highlight=xxx とすると、そのラベルを強調表示します。
#   ltsvparser.awk highlight=speed_download [ログファイル]
# ・tsv_label=datetime,speed_download... とすると、
#   入力ファイルが TSV であると仮定し、それに対して
#   指定されたラベルを付与しての LTSV/JSON 変換が行えます。
#   ltsvparser.awk tsv_label=datetime,speed_download [ログファイル]
#
# ・mode=apache/elb/cloudfront と指定すると、
#   入力ファイルが apache combined / ELB / CloudFront のログであると
#   仮定してのフォーマット解析を行います。
#
# ・mode=aws-billing と指定すると、AWS の課金データ(CSV) を読みます。
#
# date          comment
# 2014/07/09    初版作成
# 2014/07/10    ラベルのハイライト機能を追加
#               TSVを食わせて LTSV/JSON に吐く機能を追加
# 2014/07/11    format=shellenv を追加
# 2014/07/12    mode=apache (apache combined を読むモード) を追加
# 2014/07/14    mode=elb 、mode=cloudfront を追加
#               mode=squid (squid の標準ログ形式）を追加
# 2014/10/23    mode=aws-billing を追加

BEGIN {
    # 入力はタブ区切りで
    FS="\t"

    # ハイライト表示用のエスケープシーケンス
    ESC_COLOR="\033[34;1m"
    ESC_RESET="\033[0m"

    # 月の名前を数値に変換するための配列変数
    month["Jan"]=01
    month["Feb"]=02
    month["Mar"]=03
    month["Apr"]=04
    month["May"]=05
    month["Jun"]=06
    month["Jul"]=07
    month["Aug"]=08
    month["Sep"]=09
    month["Oct"]=10
    month["Nov"]=11
    month["Dec"]=12
}

########################################
# ラベル/フィールド情報の初期化処理
# ・ラベルの並べ替え順の取得
# ・ハイライト対象のラベル名処理
# ・TSV + カラム名の組み合わせによる処理
NR == 1 {

    # mode == "xxx" のデフォルトのラベル並び順定義
    if ( length(label) == 0 ) {
        if ( mode == "apache" ) {
            label="host,ident,user,datetime,req,status,size,referer,ua,cachesize,date,time,timezone,method,uri,scheme,protocol,responsetime,cachestate"
        } else if ( mode == "squid" ) {
            label="unixtime,responsetime,host,cachestatus,statuscode,size,method,uri,user,hierarchy,mime-type"
        }
    }

    # 抜出対象のラベル名の初期化
    if ( length(label) > 0 ) {
        split( label, _key_array, "," );
    }

    # ハイライト対象のラベル名の初期化
    if ( length(highlight) > 0 ) {
        COLORED_LOG=1
        split( highlight, _key_highlight_tmp, "," );

        # ラベル名を添え字とする連想配列を作る
        # これにより、あるラベル名を処理するときに
        # ハイライト処理が必要か否かをシンプルに判定できる。
        for ( i = 1 ; i <= array_length(_key_highlight_tmp) ; i++ ) {
            _key_highlight[_key_highlight_tmp[i]]=1
        }

        delete _key_highlight_tmp
    }

    # stdout がパイプやリダイレクトの場合はハイライトしない。
    if ( isatty(1) == 0 ) {
        COLORED_LOG=0
    }

    # 抜出対象のラベル名の初期化(TSVファイルのカラム名を別途指定することで、TSVも処理可能）
    if ( length(tsv_label) > 0 ) {
        split( tsv_label, _key_tsv_array, "," );
    }
}

########################################
# 一部のメジャーなログ形式を読む処理
# ・apache combined
# ・Elastic Load Balancer (準備中)
# ・Cloud Front (準備中)

####################
# apache combined 形式のログを読む。
#
# FIXME: parse したデータを LTSV に再構築するのではなく、最初から内部形式に変換すべき。
mode == "apache" {
    # $0 を " " で split する
    split( $0, _apachelog_array, " " )

    # LTSV でログを再構成
    _ltsv_array["host"] = _apachelog_array[1]
    if ( _apachelog_array[2] != "-" ) {
        _ltsv_array["ident"] = "-"
        _ltsv_array["responsetime"] = _apachelog_array[2]
    }

    _ltsv_array["user"] = _apachelog_array[3]
    _ltsv_array["datetime"] = sprintf("%s %s", _apachelog_array[4],_apachelog_array[5])

    # 6番目のカラム以降は METHOD URI PROTOCOL の文字列が来る...筈であるが、
    # apache ではリクエストヘッダの１行目の内容を %r にそのまま出力している
    # ように見えるため、"xxxxx xxxxx xxxx" という書式であると想定する
    for ( fp = 6 ; fp <= array_length(_apachelog_array) ; fp++ ) {
        _ltsv_array["req"] = _ltsv_array["req"] "" _apachelog_array[fp]

        if ( _apachelog_array[fp] ~ /"$/ ) break;

        if ( fp < array_length(_apachelog_array) ) {
            _ltsv_array["req"] = _ltsv_array["req"] " "
        }
    }
    fp++

#    if ( _apachelog_array[6] ~ /"*"$/ ) {
#        _ltsv_array["req"] = _apachelog_array[fp++]
#    } else {
#   for (
#        _ltsv_array["req"] = sprintf("%s %s %s",
#                                _apachelog_array[fp++],
#                                _apachelog_array[fp++],
#                                _apachelog_array[fp++])
#    }
    _ltsv_array["statuscode"] = _apachelog_array[fp++]
    _ltsv_array["size"] = _apachelog_array[fp++]
    _ltsv_array["referer"] = _apachelog_array[fp++]

    # 12番目のカラム以降は User-Agent の文字列が来る
    for ( i = fp ; i <= array_length(_apachelog_array) ; i++ ) {
        _ltsv_array["ua"] = _ltsv_array["ua"] "" _apachelog_array[i]

        if ( _apachelog_array[i] ~ /"$/ ) break;

        if ( i < array_length(_apachelog_array) ) {
            _ltsv_array["ua"] = _ltsv_array["ua"] " "
        }
    }

    # user-agent の後ろにもフィールドがあったら、cachestate であると仮定する
    # これは弊社仕様のログフォーマット対応のため
    if ( i < array_length(_apachelog_array) ) {
        for ( i++ ; i <= array_length(_apachelog_array) ; i++ ) {

            _ltsv_array["cachestate"] = _ltsv_array["cachestate"] _apachelog_array[i]
        }

        if ( i < array_length(_apachelog_array) ) {
            _ltsv_array["cachestate"] = _ltsv_array["cachestate"] _apachelog_array[i] " "
        }
    }

    # datetime が [日付/月/年:時:分:秒タイムゾーン] だと
    # 非常に使い辛いので、date / time / timezone に分ける
    datetime=_apachelog_array[4] " " _apachelog_array[5]
    split( datetime, _datetime_array, "[\\[/:\\] ]" )
    _ltsv_array["date"] = sprintf( "%s/%s/%s", _datetime_array[4], month[_datetime_array[3]], _datetime_array[2] )
    _ltsv_array["time"] = sprintf( "%s:%s:%s", _datetime_array[5], _datetime_array[6], _datetime_array[7] )
    _ltsv_array["timezone"] = _datetime_array[8]

    # requesturl は、メソッド/uri/prototocol に分ける
    # ibro製品の snaprec のログは uri が http://xxxx/ の形式なので
    # ここから scheme と vhost も抜くようにする。
    #split( requesturl, _url_array, "[\" ]" )
    split( _ltsv_array["req"], _url_array, "[\" ]" )
    if ( array_length(_uri_array) == 3 ) {
        _ltsv_array["method"]   = _url_array[2]
        _ltsv_array["uri"]      = _url_array[3]
        _ltsv_array["protocol"] = _url_array[4]
    } else {
        _ltsv_array["uri"]      = _url_array[2]
    }

    if ( _ltsv_array["uri"] ~ /[a-z]*:\/\// ) {
        split( _ltsv_array["uri"], _uri_array, "/" )
        _ltsv_array["scheme"] = _uri_array[1]
        _ltsv_array["vhost"] = _uri_array[3]
        _ltsv_array["uri"] = ""
        for ( i = 4 ; i <= array_length(_uri_array) ; i++ ) {
            _ltsv_array["uri"] = _ltsv_array["uri"] "/" _uri_array[i]
        }
    }

    linebuffer=""
    # 生成したデータを LTSV パーサーに渡す
    for ( i in _ltsv_array ) {
        linebuffer = linebuffer sprintf( "%s:%s\t", i, _ltsv_array[i] )
    }
    $0 = linebuffer
    delete _ltsv_array
    delete _apachelog_array
}

####################
# squid の squidlog を読む
#
# FIXME: parse したデータを LTSV に再構築するのではなく、最初から内部形式に変換すべき。
mode == "squid" {
    # $0 を " " で split する
    split( $0, _squidlog_array, " " )

    _ltsv_array["unixtime"]     = _squidlog_array[1]
    _ltsv_array["responsetime"] = _squidlog_array[2]
    _ltsv_array["host"]         = _squidlog_array[3]
    _ltsv_array["squidstatus"]  = _squidlog_array[4]
    _ltsv_array["size"]         = _squidlog_array[5]
    _ltsv_array["method"]       = _squidlog_array[6]
    _ltsv_array["uri"]          = _squidlog_array[7]
    _ltsv_array["user"]         = _squidlog_array[8]
    _ltsv_array["hierarchy"]    = _squidlog_array[9]
    _ltsv_array["mime-type"]    = _squidlog_array[10]

    split( _ltsv_array["squidstatus"], _squidstatus_array, "/" )
    _ltsv_array["cachestatus"] = _squidstatus_array[1]
    _ltsv_array["statuscode"]  = _squidstatus_array[2]

    for ( i in _ltsv_array ) {
        linebuffer = linebuffer sprintf( "%s:%s\t", i, _ltsv_array[i] )
    }
    $0 = linebuffer
    delete _ltsv_array
    delete _squidlog_array
}

####################
# AWS の ELB ログを読む。
#
# FIXME: parse したデータを LTSV に再構築するのではなく、最初から内部形式に変換すべき。
mode == "elb" {
    # $0 を " " で split する
    split( $0, _elblog_array, " " );

    # LTSV でログを再構成
    linebuffer =            sprintf("timestamp:%s\t",               _elblog_array[1])
    linebuffer = linebuffer sprintf("elb:%s\t",                     _elblog_array[2])
    linebuffer = linebuffer sprintf("clientport:%s\t",              _elblog_array[3])
    linebuffer = linebuffer sprintf("backend_port:%s\t",            _elblog_array[4])
    linebuffer = linebuffer sprintf("request_processing_time:%s\t", _elblog_array[5])
    linebuffer = linebuffer sprintf("backend_processing_time:%s\t", _elblog_array[6])
    linebuffer = linebuffer sprintf("response_processing_time:%s\t",_elblog_array[7])
    linebuffer = linebuffer sprintf("elb_status_code:%s\t",         _elblog_array[8])
    linebuffer = linebuffer sprintf("backend_status_code:%s\t",     _elblog_array[9])
    linebuffer = linebuffer sprintf("recieved_bytes:%s\t",          _elblog_array[10])
    linebuffer = linebuffer sprintf("sent_bytes:%s\t",              _elblog_array[11])
    linebuffer = linebuffer sprintf("request:%s %s %s",             _elblog_array[12], _elblog_array[13], _elblog_array[14])

    # 生成したデータを LTSV パーサーに渡す
    $0 = linebuffer
}

# AWS の CloudFront ログを読む。
mode == "cloudfront" {
    # $0 を " " で split する
    split( $0, _cflog_array, " " );

####################
    # LTSV でログを再構成
    linebuffer =            sprintf("date:%s\t",                _cflog_array[1])
    linebuffer = linebuffer sprintf("time:%s\t",                _cflog_array[2])
    linebuffer = linebuffer sprintf("x-edge-location:%s\t",     _cflog_array[3])
    linebuffer = linebuffer sprintf("sc-bytes:%s\t",            _cflog_array[4])
    linebuffer = linebuffer sprintf("c-ip:%s\t",                _cflog_array[5])
    linebuffer = linebuffer sprintf("cs-method:%s\t",           _cflog_array[6])
    linebuffer = linebuffer sprintf("cs-host:%s\t",             _cflog_array[7])
    linebuffer = linebuffer sprintf("cs-uri-stem:%s\t",         _cflog_array[8])
    linebuffer = linebuffer sprintf("sc-status:%s\t",           _cflog_array[9])
    linebuffer = linebuffer sprintf("cs-referer:%s\t",          _cflog_array[10])
    linebuffer = linebuffer sprintf("cs-useragent:%s\t",        _cflog_array[11])
    linebuffer = linebuffer sprintf("cs-uri-query:%s\t",        _cflog_array[12])
    linebuffer = linebuffer sprintf("cs-cookie:%s\t",           _cflog_array[13])
    linebuffer = linebuffer sprintf("x-edge-result-type:%s\t",  _cflog_array[14])
    linebuffer = linebuffer sprintf("x-edge-result-id:%s\t",    _cflog_array[15])
    linebuffer = linebuffer sprintf("x-host-header:%s\t",       _cflog_array[16])
    linebuffer = linebuffer sprintf("cs-protocol:%s\t",         _cflog_array[17])
    linebuffer = linebuffer sprintf("cs-bytes:%s\t",            _cflog_array[18])
    linebuffer = linebuffer sprintf("time-taken:%s",            _cflog_array[19])

    # 生成したデータを LTSV パーサーに渡す
    $0 = linebuffer
}

####################
# AWS の課金レポートを読む
#
# FIXME: parse したデータを LTSV に再構築するのではなく、最初から内部形式に変換すべき。
mode == "aws-billing" {
    if ( NR == 1 ) {
    #    label=$0

        split( $0, _aws_billing_label, "," );
        next

    } else {
        # split( $0, _awsbillinglog_array, '","' )
        sub( /^"/, "", $0 )
        sub( /"$/, "", $0 )
        split( $0, _awsbillinglog_array, "\",\"" );

        linebuffer=""
        for(i=1;i<=array_length(_awsbillinglog_array) ; i++ ) {
#            print i,$i
            linebuffer = linebuffer sprintf("%s:%s\t", _aws_billing_label[i], _awsbillinglog_array[i])
        }
        delete _awsbillinglog_array
        $0 = linebuffer
    }

}

########################################
# LTSV や TSV 形式のデータを読む処理
# 本スクリプトのメインブロックです
{
    if ( array_length(_key_tsv_array) == 0 ) {
        # LTSV パーサ処理
        # 連想配列 key, value に値を格納する
        for(i=1;i<=NF;i++) {
            match($i,":");

            # ラベル名の配列変数
            parse_key[i]=substr($i,0,RSTART-1);

            # 値の配列変数
            parse_value[i]=substr($i,RSTART+1);

            # ラベル名を添え字とする連想配列。
            parse_index[parse_key[i]]=parse_value[i];
        }
    } else {
        # TSV -> LTSV/JSON の機能もつけてみた。
        # この場合は TSV の各カラムに対応するラベルを
        # パラメータ tsv_label で引き渡す。

        for( i = 1 ; i <= array_length(_key_tsv_array) ; i++ ) {

            # ラベル名の配列変数
            parse_key[i]=_key_tsv_array[i]

            # 値の配列変数
            parse_value[i]=$i

            # ラベル名を添え字とする連想配列。
            parse_index[parse_key[i]]=parse_value[i];
        }
    }

    # ラベルやフィールド順の並べ替え処理
    if ( length(label) > 0 ) {
        # キーの並び順指定どおりに順番を並べ替える処理
        key_index=0
        for ( i = 1 ; i <= array_length(_key_array) ; i++ ) {
            if ( length(parse_index[_key_array[i]]) > 0 ) {
                key_index++
                ltsv_key[key_index]   = _key_array[i]

                # ラベルの値は、ラベル名に対応した情報が含まれる
                #ltsv_value[key_index] = parse_value[parse_index[_key_array[i]]]
                ltsv_value[key_index] = parse_index[_key_array[i]]
            }
        }
    } else {
        # キーの並び順指定が無い場合はそのまんま出す。
        for( i = 1 ; i <= array_length(parse_key) ; i++ ) {
            ltsv_key[i]=parse_key[i]
            ltsv_value[i]=parse_value[i]
        }
    }

    # フォーマット指定に基づく出力処理
    if      ( format == "tsv" )         print_tsv( ltsv_key, ltsv_value )
    else if ( format == "ltsv" )        print_ltsv( ltsv_key, ltsv_value )
    else if ( format == "shellenv" )    print_shellenv( ltsv_key, ltsv_value )
    else                                print_json( ltsv_key, ltsv_value )

    # 連想配列を破棄する。
    delete ltsv_key
    delete ltsv_value
    delete parse_key
    delete parse_value
    delete parse_index
}


############################################################
# ここから下は、データの出力形式毎の function を配置している

# LTSV出力
function print_ltsv( _ltsv_key, _ltsv_value,  i, column )
{
    if ( _ltsv_key[1] == _ltsv_value[1] ) {
        return
    }

    column=0
    for(i=1;i<=NF;i++) {
        if ( _ltsv_key[i] != ""  ) {
            # ハイライトするか否かの調整
            if ( COLORED_LOG != 0 && _key_highlight[_ltsv_key[i]] != 0 ) {
                COLOR_HIGHLIGHT=ESC_COLOR
                COLOR_RESET    =ESC_RESET
            } else {
                COLOR_HIGHLIGHT=""
                COLOR_RESET    =""
            }

            # ２番目以降のカラム出力時はセパレータの tab を最初に出す
            if ( ++column!=1 ) {
                printf "\t"
            }

            printf "%s%s:%s%s", COLOR_HIGHLIGHT, _ltsv_key[i], _ltsv_value[i], COLOR_RESET
        }
    }
    printf "\n"
}

# JSON出力
function print_json( _ltsv_key, _ltsv_value,  i, column )
{
    if ( _ltsv_key[1] == _ltsv_value[1] ) {
        return
    }

    column=0
    print "{"
    for(i=1;i<=NF;i++) {
        if ( _ltsv_key[i] != ""  ) {
            # ハイライトするか否かの調整
            if ( COLORED_LOG != 0 && _key_highlight[_ltsv_key[i]] != 0 ) {
                COLOR_HIGHLIGHT=ESC_COLOR
                COLOR_RESET    =ESC_RESET
            } else {
                COLOR_HIGHLIGHT=""
                COLOR_RESET    =""
            }

            # ２番目以降のカラム出力時はセパレータの tab を最初に出す
            if ( ++column!=1 ) {
                printf ",\n"
            }

            # 値が文字型か否かでの出力形式の調整
            if ( int(_ltsv_value[i]) == _ltsv_value[i] || _ltsv_value[i] ~ /^".*"$/ ) {
                printf "\t%s\"%s\":%s%s", COLOR_HIGHLIGHT, _ltsv_key[i], _ltsv_value[i], COLOR_RESET
            } else {
                gsub(/"/, "\\\"", _ltsv_value[i] )
                printf "\t%s\"%s\":\"%s\"%s", COLOR_HIGHLIGHT, _ltsv_key[i], _ltsv_value[i], COLOR_RESET
            }
        }
    }

    print "\n}"
}

# タブ区切りテキスト出力
function print_tsv( _ltsv_key, _ltsv_value,  i, column )
{
    if ( _ltsv_key[1] == _ltsv_value[1] ) {
        return
    }

#print _ltsv_key

    callcount++

    if ( callcount == 1 ) {
        for( i=1 ; i<= array_length(_ltsv_key) ; i++ ) {
            if ( i != 1 ) {
                printf( "\t" )
            }
            printf( "%s", _ltsv_key[i] )
        }
        printf "\n"
    }

    for(i=1;i<=array_length(_ltsv_value);i++) {
        # ハイライトするか否かの調整
        if ( COLORED_LOG != 0 && _key_highlight[_ltsv_key[i]] != 0 ) {
            COLOR_HIGHLIGHT=ESC_COLOR
            COLOR_RESET    =ESC_RESET
        } else {
            COLOR_HIGHLIGHT=""
            COLOR_RESET    =""
        }

        # ２番目以降のカラム出力時はセパレータの tab を最初に出す
        if ( i != 1 ) {
            printf( "\t" )
        }

        printf( "%s%s%s", COLOR_HIGHLIGHT, _ltsv_value[i], COLOR_RESET )
    }
        printf "\n"
}

# シェル変数への代入用文字列出力
function print_shellenv( _ltsv_key, _ltsv_value,  i, column )
{
    if ( _ltsv_key[1] == _ltsv_value[1] ) {
        return
    }

    column=0
    for(i=1;i<=NF;i++) {
        if ( _ltsv_key[i] != ""  ) {
            # ハイライトするか否かの調整
            if ( COLORED_LOG != 0 && _key_highlight[_ltsv_key[i]] != 0 ) {
                COLOR_HIGHLIGHT=ESC_COLOR
                COLOR_RESET    =ESC_RESET
            } else {
                COLOR_HIGHLIGHT=""
                COLOR_RESET    =""
            }

            # 値が文字型か否かでの出力形式の調整
            if ( int(_ltsv_value[i]) == _ltsv_value[i] ) {
                printf "%s%s=%s%s\n", COLOR_HIGHLIGHT, _ltsv_key[i], _ltsv_value[i], COLOR_RESET
            } else {
                gsub(/"/, "\\\"", _ltsv_value[i] )
                printf "%s%s=\"%s\"%s\n", COLOR_HIGHLIGHT, _ltsv_key[i], _ltsv_value[i], COLOR_RESET
            }
        }
    }
}

# システムコール isatty の実装
# test コマンドを使っている
# see also https://github.com/e36freak/awk-libs/blob/master/sys.awk
function isatty(fd) {
    # make sure fd is an int
    if (fd !~ /^[0-9]+$/) {
        return -1;
    }

    # actually test
    return !system("test -t " fd);
}

function array_length( _array ) {
    len=0
    for (e in _array) len++
    return len
}
