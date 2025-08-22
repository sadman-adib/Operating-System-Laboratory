# x=$((12+2)) #double brackets for arithmetic operations

# echo $x

# x=$(ls -1) #check all the files

# echo $x #print all the files

# echo "Enter your name"
# read name
# echo "Hello $name"

# echo "hello $1 $2 $3" # print with cli forward

# echo "hello $3 $2 $1" # print with cli reverse

# ~/workspace$ false
# ~/workspace$ echo $?
# 1
# ~/workspace$ true
# ~/workspace$ echo $?
# 0


# conditional statements

# < -> -ls (less than)
# > -> -gt (greater than)
# && -> -a (and)

# x=100

# one method
# if [ $x -gt 0 -a $x -lt 50 ]
#   then echo "x is greater than 0 and less than 50"
# else 
#   echo "not in between 0 and 50"
# fi

# another method
# if (($x>0 && x<50))
#   then echo "x is greater than 0 and less than 50"
# else echo "not in between 0 and 50"
# fi

# some another syntax

# -f file_namme = true if file_name is a regular file (.pdf, .txt etc)
# -d name = true if name is a directory
# -r file_name = true if file_name has read permission
# -w file_name = true if file_name has write permission
# -x file_name = true if file_name has execute permission


# check if file exists or not
file_name="lecture_2.sh"

if [ -f "$file_name" ]; 
  then
    echo "file exists"
else 
  echo "file does not exists"
fi





