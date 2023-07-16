package com.github.ruben_bottu.isp_class_schedule_backend.data_access;

import com.github.ruben_bottu.isp_class_schedule_backend.domain.CourseGroup;
import com.github.ruben_bottu.isp_class_schedule_backend.domain.Group;
import com.github.ruben_bottu.isp_class_schedule_backend.domain.course.Course;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class CustomCourseRepositoryImpl implements CustomCourseRepository {

    @PersistenceContext
    private EntityManager entityManager;

    @Override
    public List<List<CourseGroup>> getCourseGroupsGroupedByCourse(List<Long> courseIds) {
        Map<Long, List<CourseGroup>> courseIdWithCourseGroups = new LinkedHashMap<>();

        @SuppressWarnings("unchecked")
        List<List<CourseGroup>> courseGroupsGroupedByCourse = entityManager.createQuery("""
                        SELECT DISTINCT
                                cg.id AS cgId,
                                c.id AS cId,
                                c.name AS cName,
                                g.id AS gId,
                                g.name AS gName
                        FROM CourseEntity c JOIN CourseGroupEntity cg ON c.id = cg.course.id
                            JOIN GroupEntity g ON cg.group.id = g.id
                        WHERE c.id IN (:courseIds)
                        """)
                .setParameter("courseIds", courseIds)
                .unwrap(org.hibernate.query.Query.class)
                .setTupleTransformer((tuple, aliases) -> transformTuple(tuple, courseIdWithCourseGroups))
                .setResultListTransformer(list -> transformList(courseIdWithCourseGroups))
                .getResultList();

        return courseGroupsGroupedByCourse;
    }

    private List<CourseGroup> transformTuple(Object[] tuple, Map<Long, List<CourseGroup>> courseIdWithCourseGroups) {
        int index = -1;

        // Order has to be the same as in query
        Long courseGroupId = (Long) tuple[++index];
        Long courseId = (Long) tuple[++index];
        String courseName = (String) tuple[++index];
        Long groupId = (Long) tuple[++index];
        String groupName = (String) tuple[++index];

        var course = new Course(courseId, courseName);
        var group = new Group(groupId, groupName);
        var courseGroup = new CourseGroup(courseGroupId, course, group);

        List<CourseGroup> courseGroupsOfCourse = courseIdWithCourseGroups.computeIfAbsent(
                courseId,
                id -> new ArrayList<>()
        );

        courseGroupsOfCourse.add(courseGroup);

        return courseGroupsOfCourse;
    }

    private List<List<CourseGroup>> transformList(Map<Long, List<CourseGroup>> courseIdWithCourseGroups) {
        return new ArrayList<>(courseIdWithCourseGroups.values());
    }
}
