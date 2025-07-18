locals {
  templates = flatten([
    for tool, submap in var.template : [
      for template, path in submap : {
        tool = tool
        name = template
        path = path
      }
    ]
  ])
  template_length = length(local.templates)
}

resource "local_file" "templates" {
  count   = local.template_length
  content = try(templatefile("${path.module}/env/${terraform.workspace}/${local.templates[count.index].name}.tftpl", var.parameters), "")
  filename = abspath(
    "${path.root}/../${local.templates[count.index].tool}/${
      contains(["ansible", "kubernetes"], local.templates[count.index].tool)
      ? "env/${terraform.workspace}"
      : "${terraform.workspace}"
    }/${local.templates[count.index].path}"
  )
}

