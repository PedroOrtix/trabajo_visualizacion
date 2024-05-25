library(shiny)
library(shinydashboard)
library(readxl)
library(ggplot2)
library(dplyr)
library(plotly)
library(tidyr)
library(dashboardthemes)

ui <- dashboardPage(
  dashboardHeader(title = "Dashboard de Pacientes y Eventos"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Resumen", tabName = "resumen", icon = icon("dashboard")),
      menuItem("Análisis de Pacientes", tabName = "pacientes", icon = icon("user")),
      menuItem("Análisis de Eventos", tabName = "eventos", icon = icon("heartbeat")),
      menuItem("Otras Estadísticas", tabName = "otras_estadisticas", icon = icon("chart-bar"))
    )
  ),
  dashboardBody(
    shinyDashboardThemes(theme = "blue_gradient"),
    tabItems(
      tabItem(tabName = "resumen",
              fluidRow(
                valueBoxOutput("total_pacientes"),
                valueBoxOutput("total_eventos")
              ),
              fluidRow(
                box(plotlyOutput("plot_eventos_tipo"), width = 12)
              )
      ),
      tabItem(tabName = "pacientes",
              fluidRow(
                box(
                  title = "Filtros",
                  width = 4,
                  selectInput("sexo_pacientes", "Sexo", choices = c("All", "MALE", "FEMALE"), selected = "All"),
                  sliderInput("edad_pacientes", "Edad", min = 0, max = 100, value = c(0, 100))
                ),
                box(plotlyOutput("plot_cohorte"), width = 8)
              ),
              fluidRow(
                box(plotlyOutput("plot_seleccion_pacientes"), width = 12)
              ),
              fluidRow(
                box(dataTableOutput("tabla_paciente"), width = 12)
              )
      ),
      tabItem(tabName = "eventos",
              fluidRow(
                box(
                  title = "Filtros",
                  width = 4,
                  selectInput("clasificacion", "Clasificación de Hemorragia", 
                              choices = c("TIMI", "GUSTO", "BARC"), selected = "TIMI"),
                  selectInput("grav_hemorragia", "Gravedad de la Hemorragia", choices = "All", selected = "All"),
                  selectInput("sexo", "Sexo", choices = c("All", "MALE", "FEMALE"), selected = "All"),
                  sliderInput("edad", "Edad", min = 0, max = 100, value = c(0, 100))
                ),
                box(plotlyOutput("plot_sangrado_tipo"), width = 8)
              ),
              fluidRow(
                box(plotlyOutput("plot_torta_sangrado"), width = 12)
              ),
              fluidRow(
                box(dataTableOutput("tabla_eventos"), width = 12)
              )
      ),
      tabItem(tabName = "otras_estadisticas",
              fluidRow(
                box(plotlyOutput("plot_histograma_edad"), width = 12)
              ),
              fluidRow(
                box(plotlyOutput("plot_edad_eventos"), width = 12)
              ),
              fluidRow(
                box(plotlyOutput("plot_medicamentos"), width = 12)
              )
      )
    )
  )
)

server <- function(input, output, session) {
  observe({
    grav_choices <- unique(eventos_con_edad[[paste0("Gravedad de la hemorragia (", input$clasificacion, ")")]])
    updateSelectInput(session, "grav_hemorragia", choices = c("All", grav_choices), selected = "All")
  })
  
  output$total_pacientes <- renderValueBox({
    valueBox(
      nrow(datos_pacientes), "Total de Pacientes", icon = icon("users"),
      color = "aqua"
    )
  })
  
  output$total_eventos <- renderValueBox({
    valueBox(
      nrow(datos_eventos), "Total de Eventos", icon = icon("heartbeat"),
      color = "red"
    )
  })
  
  output$plot_eventos_tipo <- renderPlotly({
    p <- ggplot(eventos_sangrado, aes(x = `Tipo de sangrado`, y = num_eventos, fill = `Tipo de sangrado`)) +
      geom_bar(stat = "identity") +
      theme_minimal() +
      labs(title = "Número de Eventos por Tipo de Sangrado", x = "Tipo de Sangrado", y = "Número de Eventos") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    ggplotly(p)
  })
  
  filtered_pacientes <- reactive({
    data <- datos_pacientes
    if (input$sexo_pacientes != "All") {
      data <- data %>% filter(Sexo == input$sexo_pacientes)
    }
    data <- data %>% filter(Edad >= input$edad_pacientes[1] & Edad <= input$edad_pacientes[2])
    data
  })
  
  output$plot_cohorte <- renderPlotly({
    data <- filtered_pacientes() %>%
      group_by(Sexo, Edad) %>%
      summarise(num_pacientes = n(), .groups = 'drop')
    
    p <- ggplot(data, aes(x = Edad, y = Sexo, size = num_pacientes, color = Sexo)) +
      geom_point(alpha = 0.7) +
      scale_size_continuous(range = c(3, 15)) +
      scale_color_manual(values = c("MALE" = "blue", "FEMALE" = "pink")) +
      theme_minimal() +
      labs(title = "Distribución de Pacientes por Edad y Sexo", x = "Edad", y = "Sexo", size = "Cantidad de Pacientes", color = "Sexo")
    
    ggplotly(p)
  })
  
  output$plot_seleccion_pacientes <- renderPlotly({
    data <- filtered_pacientes()
    p <- ggplot(data, aes(x = Edad, y = Sexo, customdata = Paciente)) +
      geom_point(aes(size = Edad, color = Sexo), alpha = 0.7) +
      scale_size_continuous(range = c(3, 15)) +
      scale_color_manual(values = c("MALE" = "blue", "FEMALE" = "pink")) +
      theme_minimal() +
      labs(title = "Selección de Pacientes por Edad y Sexo",
           x = "Edad", y = "Sexo")
    
    ggplotly(p, source = "select") %>% layout(dragmode = "select")
  })
  
  observeEvent(event_data("plotly_selected", source = "select"), {
    selected_data <- event_data("plotly_selected", source = "select")
    if (!is.null(selected_data)) {
      selected_ids <- unique(selected_data$customdata)
      filtered_data <- datos_pacientes %>% filter(Paciente %in% selected_ids)
      output$tabla_paciente <- renderDataTable({
        filtered_data
      })
    } else {
      output$tabla_paciente <- renderDataTable({
        datos_pacientes[0, ]
      })
    }
  })
  
  filtered_data <- reactive({
    data <- eventos_con_edad
    if (input$grav_hemorragia != "All") {
      grav_column <- paste0("Gravedad de la hemorragia (", input$clasificacion, ")")
      data <- data %>% filter(.data[[grav_column]] == input$grav_hemorragia)
    }
    if (input$sexo != "All") {
      data <- data %>% filter(Sexo == input$sexo)
    }
    data <- data %>% filter(Edad >= input$edad[1] & Edad <= input$edad[2])
    data
  })
  
  output$plot_sangrado_tipo <- renderPlotly({
    data <- filtered_data()
    p <- ggplot(data, aes(x = `Tipo de sangrado`, fill = `Tipo de sangrado`)) +
      geom_bar() +
      theme_minimal() +
      labs(title = "Número de Eventos por Tipo de Sangrado", x = "Tipo de Sangrado", y = "Número de Eventos") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    ggplotly(p)
  })
  
  output$plot_torta_sangrado <- renderPlotly({
    data <- eventos_sangrado
    fig <- plot_ly(data, labels = ~`Tipo de sangrado`, values = ~num_eventos, type = 'pie', textinfo = 'label+percent', insidetextorientation = 'radial')
    fig <- fig %>% layout(title = 'Proporción de Tipos de Sangrado', showlegend = TRUE)
    fig
  })
  
  output$tabla_eventos <- renderDataTable({
    filtered_data() %>%
      select(Paciente, `Otro medicamentos`, `Tipo de sangrado`, Sexo, Edad
      )
  })
  
  output$plot_histograma_edad <- renderPlotly({
    p <- ggplot(datos_pacientes, aes(x = Edad, fill = Sexo)) +
      geom_histogram(binwidth = 5, position = "dodge", color = "black") +
      theme_minimal() +
      labs(title = "Histograma de Edades de Pacientes", x = "Edad", y = "Frecuencia")
    ggplotly(p)
  })
  
  output$plot_edad_eventos <- renderPlotly({
    edad_eventos <- eventos_con_edad %>%
      group_by(Edad) %>%
      summarise(num_eventos = n(), .groups = 'drop')
    
    p <- ggplot(edad_eventos, aes(x = Edad, y = num_eventos)) +
      geom_point(aes(size = num_eventos), color = "dodgerblue") +
      theme_minimal() +
      labs(title = "Edad vs. Número de Eventos", x = "Edad", y = "Número de Eventos")
    ggplotly(p)
  })
  
  medicamentos_usados <- datos_eventos %>%
    select(Paciente, ANTICOAGULANT_STRING, ANTIPLATELET_STRING, ANALGESIC_STRING, OTHER_STRING) %>%
    pivot_longer(cols = c(ANTICOAGULANT_STRING, ANTIPLATELET_STRING, ANALGESIC_STRING, OTHER_STRING), 
                 names_to = "Tipo_Medicamento", values_to = "Medicamento") %>%
    filter(!is.na(Medicamento)) %>%
    separate_rows(Medicamento, sep = ",") %>%
    group_by(Tipo_Medicamento, Medicamento) %>%
    summarise(count = n(), .groups = 'drop')
  
  output$plot_medicamentos <- renderPlotly({
    p <- ggplot(medicamentos_usados, aes(x = Medicamento, y = count, fill = Tipo_Medicamento)) +
      geom_bar(stat = "identity", position = "dodge", color = "black") +
      theme_minimal() +
      labs(title = "Distribución de Medicamentos Usados", x = "Medicamento", y = "Frecuencia") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    ggplotly(p)
  })
}

shinyApp(ui = ui, server = server)