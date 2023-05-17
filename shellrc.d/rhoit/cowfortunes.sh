# cowfortune
case $(($RANDOM%2)) in
    0) dialogue="say";;
    1) dialogue="think";;
esac

function mascot {
	# offensive ones: removed manually
	# head-in.cow sodomized.cow telebears.cow
    export COWPATH='/opt/homebrew/Cellar/cowsay/3.04_1/share/cows'
    ls -1 $COWPATH |shuf -n 1
    # case $(($RANDOM%6)) in
    # 	0) echo "tux";;
    # 	1) echo "default";;
    # 	2) echo "elephant";;
    # 	3) echo "koala";;
    # 	4) echo "moose";;
    # 	5) echo "dragon";;
    # esac
}

function eye {
    case $(($RANDOM%10)) in
	0) echo 'oo';;
	1) echo '$$';;
	2) echo 'zz';;
	3) echo '--';;
	4) echo '++';;
	5) echo '@@';;
	6) echo 'uu';;
	7) echo '~~';;
	8) echo '..';;
	9) echo 'xx';;

	10)echo 'eə';;
	11)echo '••';;
	12)echo '☆☆';;
	13)echo '♥♥';;
	14)echo '»«';;
	15)echo 'øø';;
    esac
}

function cowfortune {
    cow$dialogue -f "`mascot`" -e "`eye`" "`fortune -s`" # | toilet --metal -f term
}

cowfortune
