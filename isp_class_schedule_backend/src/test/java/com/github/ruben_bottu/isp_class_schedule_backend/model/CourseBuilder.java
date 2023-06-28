package com.github.ruben_bottu.isp_class_schedule_backend.model;

import com.github.ruben_bottu.isp_class_schedule_backend.data_access.Course;

public class CourseBuilder {

    public static Course with(Long id, String name) {
        var course = new Course();
        course.setId(id);
        course.setName(name);
        return course;
    }
}
