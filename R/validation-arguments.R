
#
# 5.3.1 - Argument Names                - DONE
# 5.3.2 - Argument Uniqueness           - DONE
# 5.3.3.1 - Compatible Values           - DONE
# 5.3.3.2 - Required Non-Null Arguments - DONE
validate_arguments <- function(
  argument_obj_list, field_def_obj,
  ...,
  parent_obj,
  oh,
  skip_variables = FALSE
) {

  if (
    is.null(argument_obj_list) &&
    is.null(field_def_obj$arguments)
  ) {
    return(invisible(TRUE))
  }


  if (is.null(field_def_obj$arguments)) {
    oh$error_list$add(
      "5.3.1",
      "Arguments supplied, but there are no arguments for field: ", format(field_def_obj$name),
      loc = parent_obj$loc
    )
    return(FALSE)
  }

  field_arg_map <- field_def_obj$arguments
  field_arg_map %>%
    lapply("[[", "name") %>%
    lapply(format) %>%
    unlist() ->
  names(field_arg_map)

  values_seen <- list()

  for (argument_obj in argument_obj_list) {

    arg_name <- argument_obj$name
    arg_name_str <- format(arg_name)

    # 5.3.2 - Argument Uniqueness
    if (!is.null(values_seen[[arg_name_str]])) {
      oh$error_list$add(
        "5.3.2",
        "duplicate arguments with same name: ", arg_name_str,
        loc = parent_obj$loc
      )
      return(FALSE)
    }

    arg_value <- argument_obj$value
    values_seen[[arg_name_str]] <- arg_value

    matching_arg_obj <- field_arg_map[[format(arg_name)]]

    # 5.3.1 - Argument Names
    if (is.null(matching_arg_obj)) {
      oh$error_list$add(
        "5.3.1",
        "could not find matching arg value with label: ", format(arg_name),
        " for field: ", format(field_def_obj$name),
        loc = parent_obj$loc
      )
      return(FALSE)
    }



    # 5.3.3.1 - Compatible Values
    # If value is not a Variable
    #   Let argumentName be the Name of argument.
    #   Let argumentDefinition be the argument definition provided by
    #    the parent field or definition named argumentName.
    #   Let type be the type expected by argumentDefinition.
    #   The type of literalArgument must be coercible to type.
    if (inherits(arg_value, "Variable")) {
      if (!isTRUE(skip_variables)) {
        oh$variable_validator$check_variable(arg_value, matching_arg_obj$type)
      }
      next
    }

    # check type can be coerced
    validate_value_can_be_coerced(arg_value, matching_arg_obj$type, oh = oh, rule_code = "5.3.3.1")


    if (inherits(arg_value, "ObjectValue")) {
      validate_input_object_fields(arg_value, oh = oh)
    }

  }


  # 5.3.3.2 - Required Non-Null Arguments
  # For each Field or Directive in the document.
  # Let arguments be the arguments provided by the Field or Directive.
  # Let argumentDefinitions be the set of argument definitions of that Field or Directive.
  # For each definition in argumentDefinitions:
  #   Let type be the expected type of definition.
  #   If type is Non‐Null:
  #     Let argumentName be the name of definition.
  #     Let argument be the argument in arguments named argumentName
  #     argument must exist.
  #     Let value be the value of argument.
  #     value must not be the null literal.
  for (field_arg in field_arg_map) {
    if (inherits(field_arg$type, "NonNullType")) {
      arg_value <- values_seen[[format(field_arg$name)]]
      if (
        is.null(arg_value) ||
        inherits(arg_value, "NullValue")
      ) {
        oh$error_list$add(
          "5.3.3.2",
          "null or missing argument not allowed for argument: ", format(field_arg$name),
          " for field: ", format(field_def_obj$name),
          loc = parent_obj$loc
        )
        next
      }
    }
  }


  invisible(TRUE)
}
