include pgxntool/base.mk

cat_tools: $(DESTDIR)$(datadir)/extension/cat_tools.control
$(DESTDIR)$(datadir)/extension/cat_tools.control:
	pgxn install cat_tools

GENERATED = generated/entity.dmp generated/types.sql

generated/types.sql: generated/entity.dmp

.PHONY: generated
generated: $(GENERATED)
.PHONY: meta
meta: generated
all: generated
generated/%.sql: meta/%.sql cat_tools 
	@echo 'Generating $@ from $<'
	@echo '-- THIS IS A GENERATED FILE. DO NOT EDIT!' > $@
	@echo >> $@
	@psql -qt -P format=unaligned --no-psqlrc -v ON_ERROR_STOP=1 -f $< >> $@

generated/%.dmp: meta/%.sh meta/%* cat_tools
	@echo 'Generating $@ from $<'
	@echo '-- THIS IS A GENERATED FILE. DO NOT EDIT!' > $@
	@echo '-- Generated by $<' >> $@
	@echo >> $@
	@$< >> $@
	@test -r $@
	@test `cat $@ | wc -l` -gt 40

.PHONY: genclean
genclean:
	@rm -f $(GENERATED)

BUILD_SCRIPTS = $(wildcard build/*.sql)
sql/%.sql: build/%.sh $(GENERATED) $(BUILD_SCRIPTS)
	$< > $@
