#!/bin/sh

test_description='CRLF conversion all combinations'

. ./test-lib.sh

if ! test_have_prereq EXPENSIVE
then
	skip_all="EXPENSIVE not set"
	test_done
fi

compare_files () {
	tr '\015\000' QN <"$1" >"$1".expect &&
	tr '\015\000' QN <"$2" >"$2".actual &&
	test_cmp "$1".expect "$2".actual &&
	rm "$1".expect "$2".actual
}

compare_ws_file () {
	pfx=$1
	exp=$2.expect
	act=$pfx.actual.$3
	tr '\015\000' QN <"$2" >"$exp" &&
	tr '\015\000' QN <"$3" >"$act" &&
	test_cmp $exp $act &&
	rm $exp $act
}

create_gitattributes () {
	attr=$1
	case "$attr" in
		auto)
		echo "*.txt text=auto" >.gitattributes
		;;
		text)
		echo "*.txt text" >.gitattributes
		;;
		-text)
		echo "*.txt -text" >.gitattributes
		;;
		crlf)
		echo "*.txt eol=crlf" >.gitattributes
		;;
		lf)
		echo "*.txt eol=lf" >.gitattributes
		;;
		"")
		echo >.gitattributes
		;;
		*)
		echo >&2 invalid attribute: $attr
		exit 1
		;;
	esac
}

create_NNO_files () {
	for crlf in false true input
	do
		for attr in "" auto text -text lf crlf
		do
			pfx=NNO_${crlf}_attr_${attr} &&
			cp CRLF_mix_LF ${pfx}_LF.txt &&
			cp CRLF_mix_LF ${pfx}_CRLF.txt &&
			cp CRLF_mix_LF ${pfx}_CRLF_mix_LF.txt &&
			cp CRLF_mix_LF ${pfx}_LF_mix_CR.txt &&
			cp CRLF_mix_LF ${pfx}_CRLF_nul.txt
		done
	done
}

check_warning () {
	case "$1" in
	LF_CRLF) echo "warning: LF will be replaced by CRLF" >"$2".expect ;;
	CRLF_LF) echo "warning: CRLF will be replaced by LF" >"$2".expect ;;
	'')	                                                 >"$2".expect ;;
	*) echo >&2 "Illegal 1": "$1" ; return false ;;
	esac
	grep "will be replaced by" "$2" | sed -e "s/\(.*\) in [^ ]*$/\1/" | uniq  >"$2".actual
	test_cmp "$2".expect "$2".actual
}

commit_check_warn () {
	crlf=$1
	attr=$2
	lfname=$3
	crlfname=$4
	lfmixcrlf=$5
	lfmixcr=$6
	crlfnul=$7
	pfx=crlf_${crlf}_attr_${attr}
	create_gitattributes "$attr" &&
	for f in LF CRLF LF_mix_CR CRLF_mix_LF LF_nul CRLF_nul
	do
		fname=${pfx}_$f.txt &&
		cp $f $fname &&
		git -c core.autocrlf=$crlf add $fname 2>"${pfx}_$f.err"
	done &&
	git commit -m "core.autocrlf $crlf" &&
	check_warning "$lfname" ${pfx}_LF.err &&
	check_warning "$crlfname" ${pfx}_CRLF.err &&
	check_warning "$lfmixcrlf" ${pfx}_CRLF_mix_LF.err &&
	check_warning "$lfmixcr" ${pfx}_LF_mix_CR.err &&
	check_warning "$crlfnul" ${pfx}_CRLF_nul.err
}

commit_chk_wrnNNO () {
	crlf=$1
	attr=$2
	lfwarn=$3
	crlfwarn=$4
	lfmixcrlf=$5
	lfmixcr=$6
	crlfnul=$7
	pfx=NNO_${crlf}_attr_${attr}
	#Commit files on top of existing file
	create_gitattributes "$attr" &&
	for f in LF CRLF CRLF_mix_LF LF_mix_CR CRLF_nul
	do
		fname=${pfx}_$f.txt &&
		cp $f $fname &&
		git -c core.autocrlf=$crlf add $fname 2>/dev/null &&
		git -c core.autocrlf=$crlf commit -m "commit_$fname" $fname >"${pfx}_$f.err" 2>&1
	done

	test_expect_success "commit NNO files crlf=$crlf attr=$attr LF" '
		check_warning "$lfwarn" ${pfx}_LF.err
	'
	test_expect_success "commit NNO files crlf=$crlf attr=$attr CRLF" '
		check_warning "$crlfwarn" ${pfx}_CRLF.err
	'

	test_expect_success "commit NNO files crlf=$crlf attr=$attr CRLF_mix_LF" '
		check_warning "$lfmixcrlf" ${pfx}_CRLF_mix_LF.err
	'

	test_expect_success "commit NNO files crlf=$crlf attr=$attr LF_mix_cr" '
		check_warning "$lfmixcr" ${pfx}_LF_mix_CR.err
	'

	test_expect_success "commit NNO files crlf=$crlf attr=$attr CRLF_nul" '
		check_warning "$crlfnul" ${pfx}_CRLF_nul.err
	'
}

stats_ascii () {
	case "$1" in
		LF)
		echo text-lf
		;;
		CRLF)
		echo text-crlf
		;;
		CRLF_mix_LF)
		echo text-crlf-lf
		;;
		LF_mix_CR)
		echo binary
		;;
		CRLF_nul)
		echo binary
		;;
		LF_nul)
		echo binary
		;;
		CRLF_mix_CR)
		echo binary
		;;
		*)
		echo error_invalid $1
		;;
	esac

}

check_files_in_repo () {
	crlf=$1
	attr=$2
	lfname=$3
	crlfname=$4
	lfmixcrlf=$5
	lfmixcr=$6
	crlfnul=$7
	pfx=crlf_${crlf}_attr_${attr}_ &&
	compare_files $lfname ${pfx}LF.txt &&
	compare_files $crlfname ${pfx}CRLF.txt &&
	compare_files $lfmixcrlf ${pfx}CRLF_mix_LF.txt &&
	compare_files $lfmixcr ${pfx}LF_mix_CR.txt &&
	compare_files $crlfnul ${pfx}CRLF_nul.txt
}

check_in_repo_NNO () {
	crlf=$1
	attr=$2
	lfname=$3
	crlfname=$4
	lfmixcrlf=$5
	lfmixcr=$6
	crlfnul=$7
	pfx=NNO_${crlf}_attr_${attr}_
	test_expect_success "compare_files $lfname ${pfx}LF.txt" '
		compare_files $lfname ${pfx}LF.txt
	'
	test_expect_success "compare_files $crlfname ${pfx}CRLF.txt" '
		compare_files $crlfname ${pfx}CRLF.txt
	'
	test_expect_success "compare_files $lfmixcrlf ${pfx}CRLF_mix_LF.txt" '
		compare_files $lfmixcrlf ${pfx}CRLF_mix_LF.txt
	'
	test_expect_success "compare_files $lfmixcr ${pfx}LF_mix_CR.txt" '
		compare_files $lfmixcr ${pfx}LF_mix_CR.txt
	'
	test_expect_success "compare_files $crlfnul ${pfx}CRLF_nul.txt" '
		compare_files $crlfnul ${pfx}CRLF_nul.txt
	'
}

checkout_files () {
	eol=$1
	crlf=$2
	attr=$3
	lfname=$4
	crlfname=$5
	lfmixcrlf=$6
	lfmixcr=$7
	crlfnul=$8
	create_gitattributes $attr &&
	git config core.autocrlf $crlf &&
	pfx=eol_${eol}_crlf_${crlf}_attr_${attr}_ &&
	src=crlf_false_attr__ &&
	for f in LF CRLF LF_mix_CR CRLF_mix_LF LF_nul
	do
		rm $src$f.txt &&
		if test -z "$eol"; then
			git checkout $src$f.txt
		else
			git -c core.eol=$eol checkout $src$f.txt
		fi
	done
	test_expect_success "ls-files --eol $lfname ${pfx}LF.txt" "
		cat >e <<-EOF &&
		i/text-crlf w/$(stats_ascii $crlfname) ${src}CRLF.txt
		i/text-crlf-lf w/$(stats_ascii $lfmixcrlf) ${src}CRLF_mix_LF.txt
		i/text-lf w/$(stats_ascii $lfname) ${src}LF.txt
		i/binary w/$(stats_ascii $lfmixcr) ${src}LF_mix_CR.txt
		i/binary w/$(stats_ascii $crlfnul) ${src}CRLF_nul.txt
		i/binary w/$(stats_ascii $crlfnul) ${src}LF_nul.txt
		EOF
		sort <e >expect &&
		git ls-files --eol $src* | sed -e 's!attr/[=a-z-]*!!g' -e 's/  */ /g' | sort >actual &&
		test_cmp expect actual &&
		rm e expect actual
	"
	test_expect_success "checkout core.eol=$eol core.autocrlf=$crlf gitattributes=$attr file=LF" "
		compare_ws_file $pfx $lfname    ${src}LF.txt
	"
	test_expect_success "checkout core.eol=$eol core.autocrlf=$crlf gitattributes=$attr file=CRLF" "
		compare_ws_file $pfx $crlfname  ${src}CRLF.txt
	"
	test_expect_success "checkout core.eol=$eol core.autocrlf=$crlf gitattributes=$attr file=CRLF_mix_LF" "
		compare_ws_file $pfx $lfmixcrlf ${src}CRLF_mix_LF.txt
	"
	test_expect_success "checkout core.eol=$eol core.autocrlf=$crlf gitattributes=$attr file=LF_mix_CR" "
		compare_ws_file $pfx $lfmixcr   ${src}LF_mix_CR.txt
	"
	test_expect_success "checkout core.eol=$eol core.autocrlf=$crlf gitattributes=$attr file=LF_nul" "
		compare_ws_file $pfx $crlfnul   ${src}LF_nul.txt
	"
}

# Test control characters
# NUL SOH CR EOF==^Z
test_expect_success 'ls-files --eol -o Text/Binary' '
	test_when_finished "rm e expect actual TeBi_*" &&
	STRT=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA &&
	STR=$STRT$STRT$STRT$STRT &&
	printf "${STR}BBB\001" >TeBi_127_S &&
	printf "${STR}BBBB\001">TeBi_128_S &&
	printf "${STR}BBB\032" >TeBi_127_E &&
	printf "\032${STR}BBB" >TeBi_E_127 &&
	printf "${STR}BBBB\000">TeBi_128_N &&
	printf "${STR}BBB\012">TeBi_128_L &&
	printf "${STR}BBB\015">TeBi_127_C &&
	printf "${STR}BB\015\012" >TeBi_126_CL &&
	printf "${STR}BB\015\012\015" >TeBi_126_CLC &&
	cat >e <<-EOF &&
	i/ w/binary TeBi_127_S
	i/ w/text-no-eol TeBi_128_S
	i/ w/text-no-eol TeBi_127_E
	i/ w/binary TeBi_E_127
	i/ w/binary TeBi_128_N
	i/ w/text-lf TeBi_128_L
	i/ w/binary TeBi_127_C
	i/ w/text-crlf TeBi_126_CL
	i/ w/binary TeBi_126_CLC
	EOF
	sort <e >expect &&
	git ls-files --eol -o | egrep "TeBi_" | sed -e 's!attr/[=a-z-]*!!g' -e "s/  */ /g" | sort >actual &&
	test_cmp expect actual
'

#######
test_expect_success 'setup master' '
	echo >.gitattributes &&
	git checkout -b master &&
	git add .gitattributes &&
	git commit -m "add .gitattributes" "" &&
	printf "line1\nline2\nline3"     >LF &&
	printf "line1\r\nline2\r\nline3" >CRLF &&
	printf "line1\r\nline2\nline3"   >repoMIX &&
	printf "line1\r\nline2\nline3"   >CRLF_mix_LF &&
	printf "line1\nline2\rline3"     >LF_mix_CR &&
	printf "line1\r\nline2\rline3"   >CRLF_mix_CR &&
	printf "line1Q\r\nline2\r\nline3" | q_to_nul >CRLF_nul &&
	printf "line1Q\nline2\nline3" | q_to_nul >LF_nul &&
	create_NNO_files CRLF_mix_LF CRLF_mix_LF CRLF_mix_LF CRLF_mix_LF CRLF_mix_LF &&
	git -c core.autocrlf=false add NNO_*.txt &&
	git commit -m "mixed line endings" &&
	test_tick
'



warn_LF_CRLF="LF will be replaced by CRLF"
warn_CRLF_LF="CRLF will be replaced by LF"

# WILC stands for "Warn if (this OS) converts LF into CRLF".
# WICL: Warn if CRLF becomes LF
# WAMIX: Mixed line endings: either CRLF->LF or LF->CRLF
if test_have_prereq NATIVE_CRLF
then
	WILC=LF_CRLF
	WICL=
	WAMIX=LF_CRLF
else
	WILC=
	WICL=CRLF_LF
	WAMIX=CRLF_LF
fi

#                         attr   LF        CRLF      CRLFmixLF LFmixCR   CRLFNUL
test_expect_success 'commit files empty attr' '
	commit_check_warn false ""     ""        ""        ""        ""        "" &&
	commit_check_warn true  ""     "LF_CRLF" ""        "LF_CRLF" ""        "" &&
	commit_check_warn input ""     ""        "CRLF_LF" "CRLF_LF" ""        ""
'

test_expect_success 'commit files attr=auto' '
	commit_check_warn false "auto" "$WILC"   "$WICL"   "$WAMIX"  ""        "" &&
	commit_check_warn true  "auto" "LF_CRLF" ""        "LF_CRLF" ""        "" &&
	commit_check_warn input "auto" ""        "CRLF_LF" "CRLF_LF" ""        ""
'

test_expect_success 'commit files attr=text' '
	commit_check_warn false "text" "$WILC"   "$WICL"   "$WAMIX"  "$WILC"   "$WICL"   &&
	commit_check_warn true  "text" "LF_CRLF" ""        "LF_CRLF" "LF_CRLF" ""        &&
	commit_check_warn input "text" ""        "CRLF_LF" "CRLF_LF" ""        "CRLF_LF"
'

test_expect_success 'commit files attr=-text' '
	commit_check_warn false "-text" ""       ""        ""        ""        "" &&
	commit_check_warn true  "-text" ""       ""        ""        ""        "" &&
	commit_check_warn input "-text" ""       ""        ""        ""        ""
'

test_expect_success 'commit files attr=lf' '
	commit_check_warn false "lf"    ""       "CRLF_LF" "CRLF_LF"  ""       "CRLF_LF" &&
	commit_check_warn true  "lf"    ""       "CRLF_LF" "CRLF_LF"  ""       "CRLF_LF" &&
	commit_check_warn input "lf"    ""       "CRLF_LF" "CRLF_LF"  ""       "CRLF_LF"
'

test_expect_success 'commit files attr=crlf' '
	commit_check_warn false "crlf" "LF_CRLF" ""        "LF_CRLF" "LF_CRLF" "" &&
	commit_check_warn true  "crlf" "LF_CRLF" ""        "LF_CRLF" "LF_CRLF" "" &&
	commit_check_warn input "crlf" "LF_CRLF" ""        "LF_CRLF" "LF_CRLF" ""
'

#                       attr   LF        CRLF      CRLFmixLF 	 LF_mix_CR   CRLFNUL
commit_chk_wrnNNO false ""     ""        ""        ""        	 ""        	 ""
commit_chk_wrnNNO true  ""     "LF_CRLF" ""        ""        	 ""        	 ""
commit_chk_wrnNNO input ""     ""        ""        ""        	 ""        	 ""


commit_chk_wrnNNO false "auto" "$WILC"   "$WICL"   "$WAMIX"  	 ""        	 ""
commit_chk_wrnNNO true  "auto" "LF_CRLF" ""        "LF_CRLF" 	 ""        	 ""
commit_chk_wrnNNO input "auto" ""        "CRLF_LF" "CRLF_LF" 	 ""        	 ""

commit_chk_wrnNNO false "text" "$WILC"   "$WICL"   "$WAMIX"  	 "$WILC"   	 "$WICL"
commit_chk_wrnNNO true  "text" "LF_CRLF" ""        "LF_CRLF" 	 "LF_CRLF" 	 ""
commit_chk_wrnNNO input "text" ""        "CRLF_LF" "CRLF_LF" 	 ""        	 "CRLF_LF"

commit_chk_wrnNNO false "-text" ""       ""        ""        	 ""        	 ""
commit_chk_wrnNNO true  "-text" ""       ""        ""        	 ""        	 ""
commit_chk_wrnNNO input "-text" ""       ""        ""        	 ""        	 ""

commit_chk_wrnNNO false "lf"    ""       "CRLF_LF" "CRLF_LF" 	  ""       	 "CRLF_LF"
commit_chk_wrnNNO true  "lf"    ""       "CRLF_LF" "CRLF_LF" 	  ""       	 "CRLF_LF"
commit_chk_wrnNNO input "lf"    ""       "CRLF_LF" "CRLF_LF" 	  ""       	 "CRLF_LF"

commit_chk_wrnNNO false "crlf" "LF_CRLF" ""        "LF_CRLF" 	 "LF_CRLF" 	 ""
commit_chk_wrnNNO true  "crlf" "LF_CRLF" ""        "LF_CRLF" 	 "LF_CRLF" 	 ""
commit_chk_wrnNNO input "crlf" "LF_CRLF" ""        "LF_CRLF" 	 "LF_CRLF" 	 ""

test_expect_success 'create files cleanup' '
	rm -f *.txt &&
	git -c core.autocrlf=false reset --hard
'

test_expect_success 'commit empty gitattribues' '
	check_files_in_repo false ""      LF CRLF CRLF_mix_LF LF_mix_CR CRLF_nul &&
	check_files_in_repo true  ""      LF LF   LF          LF_mix_CR CRLF_nul &&
	check_files_in_repo input ""      LF LF   LF          LF_mix_CR CRLF_nul
'

test_expect_success 'commit text=auto' '
	check_files_in_repo false "auto"  LF LF   LF          LF_mix_CR CRLF_nul &&
	check_files_in_repo true  "auto"  LF LF   LF          LF_mix_CR CRLF_nul &&
	check_files_in_repo input "auto"  LF LF   LF          LF_mix_CR CRLF_nul
'

test_expect_success 'commit text' '
	check_files_in_repo false "text"  LF LF   LF          LF_mix_CR LF_nul &&
	check_files_in_repo true  "text"  LF LF   LF          LF_mix_CR LF_nul &&
	check_files_in_repo input "text"  LF LF   LF          LF_mix_CR LF_nul
'

test_expect_success 'commit -text' '
	check_files_in_repo false "-text" LF CRLF CRLF_mix_LF LF_mix_CR CRLF_nul &&
	check_files_in_repo true  "-text" LF CRLF CRLF_mix_LF LF_mix_CR CRLF_nul &&
	check_files_in_repo input "-text" LF CRLF CRLF_mix_LF LF_mix_CR CRLF_nul
'

#                       attr    LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLFNUL
check_in_repo_NNO false ""      LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul
check_in_repo_NNO true  ""      LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul
check_in_repo_NNO input ""      LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul

check_in_repo_NNO false "auto"  LF        LF        LF           LF_mix_CR 	CRLF_nul
check_in_repo_NNO true  "auto"  LF        LF        LF           LF_mix_CR 	CRLF_nul
check_in_repo_NNO input "auto"  LF        LF        LF           LF_mix_CR 	CRLF_nul

check_in_repo_NNO false "text"  LF        LF        LF           LF_mix_CR 	LF_nul
check_in_repo_NNO true  "text"  LF        LF        LF           LF_mix_CR 	LF_nul
check_in_repo_NNO input "text"  LF        LF        LF           LF_mix_CR 	LF_nul

check_in_repo_NNO false "-text" LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul
check_in_repo_NNO true  "-text" LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul
check_in_repo_NNO input "-text" LF        CRLF      CRLF_mix_LF  LF_mix_CR 	CRLF_nul


################################################################################
# Check how files in the repo are changed when they are checked out
# How to read the table below:
# - checkout_files will check multiple files with a combination of settings
#   and attributes (core.autocrlf=input is forbidden with core.eol=crlf)
# - parameter $1 : core.eol               lf | crlf
# - parameter $2 : core.autocrlf          false | true | input
# - parameter $3 : text in .gitattributs  "" (empty) | auto | text | -text
# - parameter $4 : reference for a file with only LF in the repo
# - parameter $5 : reference for a file with only CRLF in the repo
# - parameter $6 : reference for a file with mixed LF and CRLF in the repo
# - parameter $7 : reference for a file with LF and CR in the repo (does somebody uses this ?)
# - parameter $8 : reference for a file with CRLF and a NUL (should be handled as binary when auto)

#                                            What we have in the repo:
#                                            ----------------- EOL in repo ----------------
#                                            LF    CRLF  CRLF_mix_LF  LF_mix_CR    CRLF_nul
#                   settings with checkout:
#                   core.   core.   .gitattr
#                    eol     acrlf
#                                            ----------------------------------------------
#                                            What we want to have in the working tree:
if test_have_prereq NATIVE_CRLF
then
MIX_CRLF_LF=CRLF
MIX_LF_CR=CRLF_mix_CR
NL=CRLF
LFNUL=CRLF_nul
else
MIX_CRLF_LF=CRLF_mix_LF
MIX_LF_CR=LF_mix_CR
NL=LF
LFNUL=LF_nul
fi
export CRLF_MIX_LF_CR MIX NL

checkout_files    lf      false  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      true   ""       CRLF  CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      input  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      false "auto"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      true  "auto"    CRLF  CRLF  CRLF         LF_mix_CR    LF_nul
checkout_files    lf      input "auto"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      false "text"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      true  "text"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    lf      input "text"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      false "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      true  "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      input "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      false "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      true  "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      input "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    lf      false "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    lf      true  "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    lf      input "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul

checkout_files    crlf    false  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    true   ""       CRLF  CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    false "auto"    CRLF  CRLF  CRLF         LF_mix_CR    LF_nul
checkout_files    crlf    true  "auto"    CRLF  CRLF  CRLF         LF_mix_CR    LF_nul
checkout_files    crlf    false "text"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    crlf    true  "text"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    crlf    false "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    true  "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    false "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    true  "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    crlf    false "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    crlf    true  "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul

checkout_files    ""      false  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      true   ""       CRLF  CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      input  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      false "auto"    $NL   CRLF  $MIX_CRLF_LF LF_mix_CR    LF_nul
checkout_files    ""      true  "auto"    CRLF  CRLF  CRLF         LF_mix_CR    LF_nul
checkout_files    ""      input "auto"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      false "text"    $NL   CRLF  $MIX_CRLF_LF $MIX_LF_CR   $LFNUL
checkout_files    ""      true  "text"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    ""      input "text"    LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      false "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      true  "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      input "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      false "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      true  "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      input "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    ""      false "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    ""      true  "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    ""      input "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul

checkout_files    native  false  ""       LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  true   ""       CRLF  CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  false "auto"    $NL   CRLF  $MIX_CRLF_LF LF_mix_CR    LF_nul
checkout_files    native  true  "auto"    CRLF  CRLF  CRLF         LF_mix_CR    LF_nul
checkout_files    native  false "text"    $NL   CRLF  $MIX_CRLF_LF $MIX_LF_CR   $LFNUL
checkout_files    native  true  "text"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    native  false "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  true  "-text"   LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  false "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  true  "lf"      LF    CRLF  CRLF_mix_LF  LF_mix_CR    LF_nul
checkout_files    native  false "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul
checkout_files    native  true  "crlf"    CRLF  CRLF  CRLF         CRLF_mix_CR  CRLF_nul


# Should be the last test case
test_expect_success 'ls-files --eol -d' "
	rm  crlf_false_attr__CRLF.txt crlf_false_attr__CRLF_mix_LF.txt crlf_false_attr__LF.txt .gitattributes &&
	cat >expect <<-EOF &&
	i/text-crlf w/ crlf_false_attr__CRLF.txt
	i/text-crlf-lf w/ crlf_false_attr__CRLF_mix_LF.txt
	i/text-lf w/ .gitattributes
	i/text-lf w/ crlf_false_attr__LF.txt
	EOF
	git ls-files --eol -d | sed -e 's!attr/[=a-z-]*!!g' -e 's/  */ /g' | sort >actual &&
	test_cmp expect actual &&
	rm expect actual
"


test_done
