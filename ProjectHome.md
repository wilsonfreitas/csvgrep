**csvgrep** is a command line program which enables users to execute searches on text delimited files using a rudimentary _query language_.
Its _query language_ is very bounded to simplicity and expressivity (in order to be easily comprehensible).
It is simple and easy-to-run that **csvgrep** is committed to be.
It aims at replacing both grep and awk when you are challenged to retrieve information of a text delimited file based on the content of a specific field (or column), you can get what you want using the semantic already presented into the file's underlying structure.
It is a safe pair of hands to quickly and precisely gather the information you need from a bunch of text files.

Here it goes a few comparisons with unix commands showing how **csvgrep** can safe your time and your brain and I dare say you will have fun using it.

| Task description | Unix command | csvgrep |
|:-----------------|:-------------|:--------|
| Print columns 1,2,4,6 of a csv file | `awk 'BEGIN{OFS=","} {print $1,$2,$4,$6}'` | `csvgrep '$1;$2;$4;$6'` |
| Print the second and fifth columns if <br /> first column begins with _Doe_ of a pipe <br /> delimited file | `awk 'BEGIN{OFS="|"} $1 ~ /^Doe/ {print $2,$5}'` | `csvgrep -I='|' '$1 eq /^Doe/; $2 ; $5'` |
| Print `Email-column` if `Name-column` <br /> begins with **Doe** | `-` | `csvgrep '${Name} ne /^Doe/; ${Email}'` |
| Check if the number of input columns <br /> remain constant | `awk 'NF == 1 {l=NF} NF > 1 {if (l!=NF) print NR}'` | `csvgrep -C '@header $NR == 1'` |

These examples are simpler than the real world task you are going to face and despite its simplicity they may give a good idea on how **csvgrep** can help you.

**csvgrep** can do this and much more. So, what are you waiting for? Don't waste your time! Give **csvgrep** a try, I am bounded to believe that it will help you.