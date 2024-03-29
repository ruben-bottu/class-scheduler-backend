package com.github.ruben_bottu.class_scheduler_backend.domain.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.HashSet;
import java.util.Set;

public class NoDuplicatesConstraintValidator implements ConstraintValidator<NoDuplicates, Iterable<?>> {

    private <E> boolean containsDuplicates(Iterable<E> iterable) {
        Set<E> set = new HashSet<>();
        for (E element : iterable) {
            if (!set.add(element)) return true;
        }
        return false;
    }

    @Override
    public boolean isValid(Iterable<?> iterable, ConstraintValidatorContext context) {
        return !containsDuplicates(iterable);
    }
}
