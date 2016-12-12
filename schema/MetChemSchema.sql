/* Drop Tables */

DROP TABLE IF EXISTS NAME;
DROP TABLE IF EXISTS SUBSTANCE;
DROP TABLE IF EXISTS COMPOUND;
DROP TABLE IF EXISTS LIBRARY;

/* Create Tables */

CREATE TABLE COMPOUND
(
	COMPOUND_ID SERIAL NOT NULL,
	MONOISOTOPIC_MASS DECIMAL NOT NULL,
	MOLECULAR_FORMULA VARCHAR NOT NULL,
	SMILES VARCHAR NOT NULL,
	INCHI VARCHAR NOT NULL,
	-- First part of the InChi key (skeleton)
	INCHI_KEY_1 VARCHAR(14) NOT NULL,
	-- Second part
	INCHI_KEY_2 VARCHAR(10) NOT NULL,
	-- The last part of the InChI key.
	INCHI_KEY_3 VARCHAR(1),
	INCHI_KEY VARCHAR(27) NOT NULL
) WITHOUT OIDS;

ALTER SEQUENCE COMPOUND_COMPOUND_ID_SEQ INCREMENT 1 MINVALUE 0;


CREATE TABLE LIBRARY
(
	LIBRARY_ID SERIAL NOT NULL,
	LIBRARY_NAME VARCHAR,
	LAST_UPDATED DATE,
	LIBRARY_LINK VARCHAR
) WITHOUT OIDS;


CREATE TABLE NAME
(
	NAME VARCHAR,
	SUBSTANCE_ID INTEGER NOT NULL
) WITHOUT OIDS;


CREATE TABLE SUBSTANCE
(
	SUBSTANCE_ID SERIAL NOT NULL,
	LIBRARY_ID INTEGER NOT NULL,
	COMPOUND_ID INTEGER NOT NULL,
	ACCESSION VARCHAR,
	PRIMARY KEY (SUBSTANCE_ID),
	UNIQUE (ACCESSION)
) WITHOUT OIDS;

/* Comments */

COMMENT ON COLUMN COMPOUND.INCHI_KEY_1 IS 'First part of the InChi key (skeleton)';
COMMENT ON COLUMN COMPOUND.INCHI_KEY_2 IS 'Second part';
COMMENT ON COLUMN COMPOUND.INCHI_KEY_3 IS 'The last part of the InChI key.';

/* Insert standard database which are imported */
insert into library(library_name,last_updated,library_link) values ('kegg',date('1970-01-01'),'http://www.kegg.jp');
insert into library(library_name,last_updated,library_link) values ('pubchem',date('1970-01-01'),'https://pubchem.ncbi.nlm.nih.gov');
insert into library(library_name,last_updated,library_link) values ('chebi',date('1970-01-01'),'https://www.ebi.ac.uk/chebi');
