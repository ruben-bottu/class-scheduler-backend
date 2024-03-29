BEGIN;

CREATE SCHEMA IF NOT EXISTS isp_class_schedule;
SET
search_path TO isp_class_schedule;


CREATE TABLE courses
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(255) NOT NULL,

    CONSTRAINT courses_pk_id PRIMARY KEY (id),
    CONSTRAINT courses_unique_name UNIQUE (name)
);


CREATE TABLE class_groups
(
    id   BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(255) NOT NULL,

    CONSTRAINT class_groups_pk_id PRIMARY KEY (id),
    CONSTRAINT class_groups_unique_name UNIQUE (name)
);


CREATE TABLE lessons
(
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    start_timestamp TIMESTAMP NOT NULL,
    end_timestamp   TIMESTAMP NOT NULL,
    course_id       BIGINT    NOT NULL,
    class_group_id  BIGINT    NOT NULL,

    CONSTRAINT lessons_pk_id PRIMARY KEY (id),
    CONSTRAINT lessons_fk_courses FOREIGN KEY (course_id) REFERENCES courses (id),
    CONSTRAINT lessons_fk_class_groups FOREIGN KEY (class_group_id) REFERENCES class_groups (id),
    CONSTRAINT lessons_unique_start_course_class_group UNIQUE (start_timestamp, course_id, class_group_id),
    CONSTRAINT lessons_check_start_before_end CHECK (start_timestamp <= end_timestamp)
);


INSERT INTO courses
VALUES (default, 'Algo'),
       (default, 'Web 1'),
       (default, 'BOP'),
       (default, 'Data 1'),
       (default, 'Testing');

INSERT INTO class_groups
VALUES (default, 'ME-1TI/1'),
       (default, 'ME-1TI/2'),
       (default, 'ME-1TI/3'),
       (default, 'ME-2TI/5');

INSERT INTO lessons (start_timestamp, end_timestamp, course_id, class_group_id)
VALUES ('2022-06-26 08:00:00', '2022-06-26 10:00:00', 1, 1),
       ('2022-06-26 10:00:00', '2022-06-26 12:00:00', 2, 1),
       ('2022-06-26 14:00:00', '2022-06-26 16:00:00', 3, 1),

       ('2022-06-26 10:00:00', '2022-06-26 12:00:00', 1, 2),
       ('2022-06-26 12:00:00', '2022-06-26 14:00:00', 2, 2),
       ('2022-06-26 14:00:00', '2022-06-26 16:00:00', 3, 2),

       ('2022-06-26 08:00:00', '2022-06-26 10:00:00', 3, 3),
       ('2022-06-26 12:00:00', '2022-06-26 14:00:00', 1, 3),
       ('2022-06-26 14:00:00', '2022-06-26 16:00:00', 2, 3),

       ('2022-06-26 08:00:00', '2022-06-26 10:00:00', 4, 4),
       ('2022-06-26 10:00:00', '2022-06-26 12:00:00', 5, 4);


CREATE TYPE IF NOT EXISTS course_id_class_group_id AS (course_id BIGINT, class_group_id BIGINT);
CREATE TYPE IF NOT EXISTS course_name_class_group_name AS (course_name VARCHAR(255), class_group_name VARCHAR(255));

-- Returns the number of collisions / overlaps between the lessons of the selected (course_id, class_group_id) pairs.
CREATE
OR REPLACE FUNCTION count_collisions(combination course_id_class_group_id ARRAY) RETURNS INT
	AS $$
	WITH selected_lessons AS (
		SELECT id, start_timestamp, end_timestamp
		FROM unnest(combination) INNER JOIN lessons USING (course_id, class_group_id)
	)
SELECT count(*) / 2 AS collision_count
FROM selected_lessons s1
         INNER JOIN selected_lessons s2 ON s1.id <> s2.id
WHERE (s1.start_timestamp, s1.end_timestamp) OVERLAPS
      (s2.start_timestamp, s2.end_timestamp);
$$
LANGUAGE SQL;

CREATE
OR REPLACE FUNCTION get_class_groups_of_course(course_id BIGINT) RETURNS SETOF course_id_class_group_id
	AS $$
SELECT DISTINCT course_id, class_group_id
FROM lessons
WHERE course_id = $1;
$$
LANGUAGE SQL;

-- Constructs the query that will generate all possible combinations of courses and class groups
-- by CROSS JOIN-ing them all toghether and turning them into arrays for ease of use.
CREATE
OR REPLACE FUNCTION construct_generate_course_class_group_combinations_query(selected_course_ids BIGINT ARRAY) RETURNS TEXT
	AS $$
	DECLARE
number_of_courses	INT	 	DEFAULT array_length(selected_course_ids, 1);
		select_array
TEXT ARRAY 	DEFAULT ARRAY[]::TEXT[];
		from_array
TEXT ARRAY 	DEFAULT ARRAY[]::TEXT[];
BEGIN
FOR i IN 1..number_of_courses LOOP
			select_array 	:= select_array || FORMAT('(s%1$s.course_id, s%1$s.class_group_id)', i);
			from_array
:= from_array 	|| FORMAT('get_class_groups_of_course(%s) s%s', selected_course_ids[i], i);
END LOOP;

RETURN FORMAT('SELECT CAST (ARRAY [%s] AS course_id_class_group_id ARRAY) AS combination FROM %s',
              array_to_string(select_array, ','),
              array_to_string(from_array, ' CROSS JOIN '));
END;
	$$
LANGUAGE plpgsql; -- IMMUTABLE

CREATE
OR REPLACE FUNCTION generate_course_class_group_combinations(course_ids BIGINT ARRAY) RETURNS TABLE(combination course_id_class_group_id ARRAY)
	AS $$
BEGIN
RETURN QUERY EXECUTE construct_generate_course_class_group_combinations_query(course_ids);
END;
	$$
LANGUAGE plpgsql;

-- Maps the given course and class group ids to their corresponding names.
CREATE
OR REPLACE FUNCTION map_course_and_class_group_ids_to_names(combination course_id_class_group_id ARRAY) RETURNS course_name_class_group_name ARRAY
	AS $$
SELECT array_agg(CAST((c.name, cg.name) AS course_name_class_group_name) ORDER BY c.id)
FROM unnest(combination)
         INNER JOIN class_groups cg ON class_group_id = cg.id
         INNER JOIN courses c ON course_id = c.id $$
	LANGUAGE SQL;

-- Returns the number of collisions / overlaps of each combination.
CREATE
OR REPLACE FUNCTION get_combinations_with_collision_count(row_limit INT, course_ids BIGINT ARRAY)
	RETURNS TABLE(collision_count INT, combination course_name_class_group_name ARRAY)
	AS $$
SELECT count_collisions(combination), map_course_and_class_group_ids_to_names(combination)
FROM generate_course_class_group_combinations(course_ids) AS combinations
ORDER BY 1, 2
    FETCH FIRST row_limit ROWS ONLY;
$$
LANGUAGE SQL;

CREATE
OR REPLACE FUNCTION get_combinations_with_collision_count_json(row_limit INT, VARIADIC course_ids BIGINT ARRAY) RETURNS TEXT
	AS $$
SELECT json_agg(to_json(c))
FROM get_combinations_with_collision_count(row_limit, course_ids) AS c $$
	LANGUAGE SQL;

COMMIT;
