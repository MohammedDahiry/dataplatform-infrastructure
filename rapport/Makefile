MAIN = main
LATEX = pdflatex
BIBER = biber

.PHONY: all clean pdf

all: pdf

pdf:
	$(LATEX) -interaction=nonstopmode $(MAIN).tex || true
	-$(BIBER) $(MAIN) 2>/dev/null || true
	$(LATEX) -interaction=nonstopmode $(MAIN).tex || true
	$(LATEX) -interaction=nonstopmode $(MAIN).tex || true
	@test -f $(MAIN).pdf && echo "OK: $(MAIN).pdf généré"

clean:
	rm -f $(MAIN).{aux,bbl,blg,log,out,toc,lof,lot,bcf,run.xml,synctex.gz}
