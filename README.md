# Personal Azure Bicep/ARM Templates

This repo will contain all of my personal Azure Bicep templates and their compiled ARM templates.

## 📂 Repo Layout

To separate out the Bicep template files from the compiled ARM templates, the two are stored in different directories:

| Directory | Purpose |
| --- | --- |
| [**`templates/`**](templates/) | This is where the **Bicep** templates are stored. |
| [**`compiled-templates/`**](compiled-templates/) | This is where the compiled **ARM** templates are stored. |

The ARM templates are compiled from the Bicep templates. If a Bicep template is stored in the `templates/bastion` directory, the compiled ARM template will be located in the `compiled-templates/bastion` directory.

## 🔑 License

The templates in this repo are licensed with the [MIT License](LICENSE).
