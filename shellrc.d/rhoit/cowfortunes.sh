# cowfortune
case $(($RANDOM%2)) in
    0) dialogue="say";;
    1) dialogue="think";;
esac

function mascot {
    case $(($RANDOM%5)) in
	0) echo "tux";;
	1) echo "default";;
	2) echo "elephant";;
	3) echo "koala";;
	4) echo "moose";;
    esac
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
