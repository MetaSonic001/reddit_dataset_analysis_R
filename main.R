# Install and load required packages
if (!require(pacman)) install.packages("pacman")
pacman::p_load(
  tidyverse, shiny, tidytext, lubridate, wordcloud2, textdata, igraph, 
  plotly, readxl, DT, reshape2, ggplot2, shinythemes, scales
)

# Read data
comments_df <- read_excel("C:/Users/shaun/OneDrive/Documents/final_reddit_project/the-reddit-dataset-dataset-comments.xlsx")
posts_df <- read_excel("C:/Users/shaun/OneDrive/Documents/final_reddit_project/the-reddit-dataset-dataset-posts.xlsx")

# Data preprocessing
comments_df$created_utc <- as.POSIXct(comments_df$created_utc, origin="1970-01-01")
posts_df$created_utc <- as.POSIXct(posts_df$created_utc, origin="1970-01-01")

# Enhanced Text Analysis
text_analysis <- list(
  comment_words = comments_df %>%
    unnest_tokens(word, body) %>%
    anti_join(stop_words) %>%
    count(word, sort = TRUE) %>%
    head(100),
  
  sentiment_analysis = comments_df %>%
    group_by(subreddit.name) %>%
    summarise(
      avg_sentiment = mean(sentiment, na.rm = TRUE),
      total_comments = n()
    ) %>%
    arrange(desc(total_comments)) %>%
    head(20)
)

# Enhanced Temporal Analysis
temporal_analysis <- list(
  hourly_activity = comments_df %>%
    mutate(hour = hour(created_utc)) %>%
    count(hour),
  
  weekly_pattern = comments_df %>%
    mutate(weekday = wday(created_utc, label = TRUE)) %>%
    count(weekday),
  
  timeline = comments_df %>%
    mutate(date = as.Date(created_utc)) %>%
    group_by(date) %>%
    summarise(
      comments = n(),
      avg_sentiment = mean(sentiment, na.rm = TRUE),
      avg_score = mean(score, na.rm = TRUE)
    )
)

# Enhanced User Analysis
user_analysis <- list(
  subreddit_stats = comments_df %>%
    group_by(subreddit.name) %>%
    summarise(
      total_comments = n(),
      avg_sentiment = mean(sentiment, na.rm = TRUE),
      avg_score = mean(score, na.rm = TRUE),
      unique_users = n_distinct(id)
    ) %>%
    arrange(desc(total_comments)),
  
  sentiment_distribution = comments_df %>%
    ggplot(aes(x = sentiment)) +
    geom_histogram(bins = 50, fill = "skyblue") +
    theme_minimal()
)

# UI
ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel("Advanced Reddit Analysis Dashboard"),
  
  navbarPage("Reddit Analysis",
             tabPanel("Overview",
                      fluidRow(
                        column(3,
                               wellPanel(
                                 h4("Dataset Statistics"),
                                 textOutput("total_comments"),
                                 textOutput("total_posts"),
                                 textOutput("unique_subreddits")
                               )
                        ),
                        column(9,
                               plotlyOutput("activity_heatmap", height = "400px")
                        )
                      )
             ),
             
             tabPanel("Text Analysis",
                      sidebarLayout(
                        sidebarPanel(
                          selectInput("text_viz_type", "Visualization Type:",
                                      choices = c("Word Cloud", "Word Frequency", "Sentiment Distribution")),
                          sliderInput("top_n_words", "Number of Words:", 
                                      min = 10, max = 100, value = 50)
                        ),
                        mainPanel(
                          plotlyOutput("text_plot", height = "600px"),
                          wordcloud2Output("wordcloud")
                        )
                      )
             ),
             
             tabPanel("Temporal Patterns",
                      sidebarLayout(
                        sidebarPanel(
                          radioButtons("time_granularity", "Time Granularity:",
                                       choices = c("Hourly", "Daily", "Weekly")),
                          checkboxInput("show_sentiment", "Show Sentiment", FALSE)
                        ),
                        mainPanel(
                          plotlyOutput("temporal_plot", height = "500px"),
                          plotlyOutput("pattern_plot", height = "300px")
                        )
                      )
             ),
             
             tabPanel("User & Subreddit Analysis",
                      sidebarLayout(
                        sidebarPanel(
                          selectInput("user_metric", "Analysis Metric:",
                                      choices = c("Comments", "Sentiment", "Score", "Activity")),
                          numericInput("top_n", "Top N Subreddits:", value = 20, min = 5, max = 50)
                        ),
                        mainPanel(
                          plotlyOutput("user_plot", height = "600px"),
                          DTOutput("subreddit_table")
                        )
                      )
             )
  )
)

# Server
server <- function(input, output) {
  # Overview Stats
  output$total_comments <- renderText({
    paste("Total Comments:", nrow(comments_df))
  })
  
  output$total_posts <- renderText({
    paste("Total Posts:", nrow(posts_df))
  })
  
  output$unique_subreddits <- renderText({
    paste("Unique Subreddits:", n_distinct(comments_df$subreddit.name))
  })
  
  # Activity Heatmap
  output$activity_heatmap <- renderPlotly({
    comments_df %>%
      mutate(
        hour = hour(created_utc),
        weekday = wday(created_utc, label = TRUE)
      ) %>%
      count(hour, weekday) %>%
      ggplot(aes(x = hour, y = weekday, fill = n)) +
      geom_tile() +
      scale_fill_viridis_c() +
      theme_minimal() +
      labs(title = "Activity Heatmap", x = "Hour of Day", y = "Day of Week")
  })
  
  # Text Analysis Visualizations
  output$text_plot <- renderPlotly({
    if(input$text_viz_type == "Word Frequency") {
      text_analysis$comment_words %>%
        head(input$top_n_words) %>%
        ggplot(aes(x = reorder(word, n), y = n)) +
        geom_col(fill = "skyblue") +
        coord_flip() +
        theme_minimal() +
        labs(title = "Word Frequency", x = "Word", y = "Count")
    } else if(input$text_viz_type == "Sentiment Distribution") {
      ggplotly(user_analysis$sentiment_distribution)
    }
  })
  
  output$wordcloud <- renderWordcloud2({
    if(input$text_viz_type == "Word Cloud") {
      wordcloud2(data = head(text_analysis$comment_words, input$top_n_words))
    }
  })
  
  # Temporal Analysis Plots
  output$temporal_plot <- renderPlotly({
    if(input$time_granularity == "Hourly") {
      p <- ggplot(temporal_analysis$hourly_activity, 
                  aes(x = hour, y = n)) +
        geom_line() +
        theme_minimal() +
        labs(title = "Hourly Activity Pattern")
    } else if(input$time_granularity == "Weekly") {
      p <- ggplot(temporal_analysis$weekly_pattern,
                  aes(x = weekday, y = n)) +
        geom_bar(stat = "identity") +
        theme_minimal() +
        labs(title = "Weekly Activity Pattern")
    } else {
      p <- ggplot(temporal_analysis$timeline,
                  aes(x = date, y = comments)) +
        geom_line() +
        theme_minimal() +
        labs(title = "Daily Activity Pattern")
    }
    ggplotly(p)
  })
  
  # User Analysis Visualizations
  output$user_plot <- renderPlotly({
    data <- head(user_analysis$subreddit_stats, input$top_n)
    
    if(input$user_metric == "Comments") {
      y_var <- "total_comments"
      title <- "Top Subreddits by Comment Count"
    } else if(input$user_metric == "Sentiment") {
      y_var <- "avg_sentiment"
      title <- "Subreddit Sentiment Analysis"
    } else {
      y_var <- "avg_score"
      title <- "Average Score by Subreddit"
    }
    
    p <- ggplot(data, aes_string(x = "reorder(subreddit.name, total_comments)", 
                                 y = y_var)) +
      geom_bar(stat = "identity", fill = "skyblue") +
      coord_flip() +
      theme_minimal() +
      labs(title = title, x = "Subreddit", y = y_var)
    
    ggplotly(p)
  })
  
  output$subreddit_table <- renderDT({
    datatable(head(user_analysis$subreddit_stats, input$top_n),
              options = list(pageLength = 10))
  })
}

# Run the app
shinyApp(ui = ui, server = server)