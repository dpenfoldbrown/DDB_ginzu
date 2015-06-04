DELIMITER $$
DROP PROCEDURE IF EXISTS sp_get_structure$$
CREATE PROCEDURE sp_get_structure(IN l_id INT) READS SQL DATA
BEGIN
	DECLARE l_db_name VARCHAR(50);
	DECLARE l_table_name VARCHAR(50);
	DECLARE l_column_name VARCHAR(50);
	DECLARE l_statement VARCHAR(255);
	DECLARE l_map_key INT;
	DECLARE l_table_id INT;

	SELECT map_key,id INTO l_map_key,l_table_id FROM structureIndex WHERE id = l_id;
	SELECT db,table_name,ar_column INTO l_db_name,l_table_name,l_column_name FROM structureIndexMap WHERE id = l_map_key;
	SELECT CONCAT("SELECT UNCOMPRESS(",l_column_name,") FROM ",l_db_name,".",l_table_name," WHERE id = ",l_table_id) INTO l_statement;
	SET @stat =l_statement;
	PREPARE get_str FROM @stat;
	EXECUTE get_str;
END$$

DROP PROCEDURE IF EXISTS get_structure$$
CREATE PROCEDURE get_structure(IN i_structure_key INT) READS SQL DATA
BEGIN
	SELECT UNCOMPRESS(struct.compress_file_content) AS file_content FROM ddbMeta.structure struct WHERE id = i_structure_key;
END$$

DROP PROCEDURE IF EXISTS get_psipred_prediction$$
CREATE PROCEDURE get_psipred_prediction(IN i_sequence_key INT) READS SQL DATA
BEGIN
	SELECT psipred.prediction AS prediction FROM ddbMeta.sequencePsiPred psipred WHERE sequence_key = i_sequence_key;
END$$

DROP PROCEDURE IF EXISTS get_fragment$$
CREATE PROCEDURE get_fragment(IN i_fragment_key INT) READS SQL DATA
BEGIN
	SELECT UNCOMPRESS(ff.compress_file_content) AS file_content FROM bddbDecoy.fragmentFile ff WHERE id = i_fragment_key;
END$$

DROP PROCEDURE IF EXISTS get_sequence$$
CREATE PROCEDURE get_sequence(IN i_sequence_key INT) READS SQL DATA
BEGIN
	SELECT seq.sequence AS sequence FROM ddbMeta.sequence seq WHERE id = i_sequence_key;
END$$

DROP PROCEDURE IF EXISTS get_run_options$$
CREATE PROCEDURE get_run_options(IN i_rid INT) READS SQL DATA
BEGIN
	SELECT runop.run_type AS run_type,runop.outfile_key AS outfile_key, runop.sequence_key AS sequence_key,runop.native_structure_key AS native_structure_key,runop.fragmentFile03_key as fragmentFile03_key,runop.fragmentFile09_key AS fragmentFile09_key,runop.n_struct AS n_struct FROM bddb.rosettaRunOptions runop WHERE id = i_rid;
END$$

DROP PROCEDURE IF EXISTS save_decoy$$
CREATE PROCEDURE save_decoy(IN i_outfile_key INT,IN i_sequence_key INT, IN i_decoy LONGTEXT) MODIFIES SQL DATA
BEGIN
	INSERT bddbDecoy.tmpdecoy (outfile_key,sequence_key,sha1,compress_silent_decoy) VALUES (i_outfile_key,i_sequence_key,SHA1(i_decoy),COMPRESS(i_decoy));
END$$

DROP PROCEDURE IF EXISTS get_decoy_data$$
CREATE PROCEDURE get_decoy_data(IN i_decoy_key INT) READS SQL DATA
BEGIN
	SELECT decoy.sequence_key AS sequence_key,seq.sequence AS sequence,UNCOMPRESS(decoy.compress_silent_decoy) AS decoy FROM bddbDecoy.decoy decoy INNER JOIN ddbMeta.sequence seq ON decoy.sequence_key = seq.id WHERE decoy.id = i_decoy_key;
END$$

DELIMITER ;

