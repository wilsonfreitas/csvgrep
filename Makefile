
all: csvgrep-v1.0.zip csvgrep-tests-v1.0.zip

csvgrep-v1.0.zip: csvgrep.pl LICENSE README
	zip -9r csvgrep-v1.0.zip csvgrep.pl LICENSE README

csvgrep-tests-v1.0.zip: tests/
	zip -9r csvgrep-tests-v1.0.zip tests -x tests/csvgrep-test.sh 

clean:
	rm -f csvgrep-v1.0.zip csvgrep-tests-v1.0.zip

