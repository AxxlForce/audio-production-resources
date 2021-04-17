#/bin/bash


move_to_folder() {

	if ls *"$1"*.wav 1> /dev/null 2>&1; then
		mkdir "$1"
    else 
    	echo "no $1 in directory"
    	return
	fi

	for file in *"$1"*.wav; do
	    mv "$file" "$1"/
	done
}

do_for_dir() {

	cd "$d"
	move_to_folder "extra hard"
	move_to_folder "hard"
	move_to_folder "medium"
	move_to_folder "extra soft"
	move_to_folder "soft"
	cd ..
}


for d in */ ; do
	do_for_dir "$d"
done
