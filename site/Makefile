
all: index.html

index.html: main.text
	multimarkdown main.text | sed 's,file://localhost/Users/wilson/dev/csvgrep/site/,,' > index.html

deploy: index.html
	cp index.html style.css ~/Sites/aw/csvgrep

clean:
	rm index.html

