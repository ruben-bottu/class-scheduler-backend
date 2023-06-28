package com.github.ruben_bottu.isp_class_schedule_backend;

import com.github.ruben_bottu.isp_class_schedule_backend.model.algorithm.Search;
import com.github.ruben_bottu.isp_class_schedule_backend.model.courses.CourseRepository;
import com.github.ruben_bottu.isp_class_schedule_backend.model.lessons.LessonRepository;
import com.github.ruben_bottu.isp_class_schedule_backend.model.ClassScheduleService;
import jakarta.validation.Validator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.dao.annotation.PersistenceExceptionTranslationPostProcessor;

@Configuration
public class ApplicationConfiguration {

    @Bean
    public Search search() {
        return new Search();
    }

    @Bean
    public ClassScheduleService classScheduleService(CourseRepository courseRepo, LessonRepository lessonRepo, Validator validator, Search search) {
        return new ClassScheduleService(courseRepo, lessonRepo, validator, search);
    }

    @Bean
    public PersistenceExceptionTranslationPostProcessor exceptionTranslation() {
        return new PersistenceExceptionTranslationPostProcessor();
    }
}
