# get rid of any sources you don't want in analysis
subset_source_profiles <- function(drop_sources) {
  dat <- pah::source_profiles %>%
    select(-drop_sources)
  
  return(dat)
}

# remove all samples where there is a zero - meaning BDL
prep_profiles <- function(pah_dat) {
  pah_dat <- filter(pah_dat, sourceProfile12 == TRUE) # keep only chemicals in source profiles
  pah_dat.remove <- unique(pah_dat$unique_id[pah_dat$RESULT == 0]) # get rid of pah_dat BDL
  pah_dat <- filter(pah_dat, !(unique_id %in% pah_dat.remove))
  pah_dat <- select(pah_dat, unique_id, RESULT, casrn, Lake, State, Watershed) #narrow columns
  return(pah_dat)
}

# function to pull out pah 16 compounds and order samples by totals
# then group totals into bins for later plotting
prep_totals <- function(pah_dat) {
  samples_16 <- filter(pah_dat, PARAM_SYNONYM == 'Priority Pollutant PAH') %>%
    arrange(RESULT)
  samples_16 <- select(samples_16, unique_id, RESULT) %>%
    group_by(unique_id) %>%
    summarize(Priority16 = mean(RESULT)) %>%
    mutate(Priority16_bin = ntile(Priority16, 4))
  
  # summarize by bin
  summary_16 <- group_by(samples_16, Priority16_bin) %>%
    summarize(round(max(Priority16), 0))
  
  samples_16$Priority16_bin[samples_16$Priority16_bin == 1] <- "Low (< 443 ppb)"
  samples_16$Priority16_bin[samples_16$Priority16_bin == 2] <- "Med (443-2489 ppb)"
  samples_16$Priority16_bin[samples_16$Priority16_bin == 3] <- "Med (2489-13426 ppb)"
  samples_16$Priority16_bin[samples_16$Priority16_bin == 4] <- "High (>13426 ppb)"
  
  # order the factor
  samples_16$Priority16_bin <- factor(samples_16$Priority16_bin, levels = c("Low (< 443 ppb)","Med (443-2489 ppb)",
                                                                            "Med (2489-13426 ppb)","High (>13426 ppb)"))
  return(samples_16)
}

profile_plotter <- function(totals = prepped_totals, filename, filter = NA, 
                            profile_dat, plot_type, sources_plot, samples_plot, sample_column) {
  
  if (!is.na(filter)) {
    sites.keep <- totals$unique_id[grep(filter, totals$Priority16_bin)]
    profile_dat[[1]] <- filter(profile_dat[[1]], unique_id %in% sites.keep)
  }
  p <- plot_profiles(profile_dat, plot_type, sources_plot, samples_plot, sample_column)
  ggsave(filename, p, height = 7, width = 10)
}


plot_conc_chi2 <- function(filename, profile_dat, totals = prepped_totals) {
  temp <- profile_dat[[2]]
  temp <- filter(temp, !(source %in% c("Creosote_product", 'Creosote_railway_ties')))
  temp <- left_join(temp, totals)
  order <- group_by(temp, source) %>%
    summarize(mean_diff = mean(sum_chi2)) %>%
    arrange(mean_diff)
  
  temp$source <- factor(temp$source, levels = order$source)
  p <- ggplot(temp, aes(x = Priority16, y = sum_chi2)) +
    geom_point() +
    facet_wrap(~source, nrow = 4, scales = 'free_y') +
    scale_x_continuous(trans = 'log10') +
    theme_bw() +
    theme(panel.grid.minor.y = element_blank(), panel.grid.minor.x = element_blank()) +
    labs(y = 'Sum Chi2', x = 'PAH16 Concentration (ppb)')
  
  ggsave(filename, p, height = 7, width = 11)
}

# boxplot but facet by concentration
facet_by_conc <- function(filename, profile_dat, totals) {
  temp_dat <- profile_dat
  temp_dat[[2]] <- left_join(temp_dat[[2]], totals, by = 'unique_id') %>%
    ungroup()
  
  
  p <- plot_profiles(temp_dat, plot_type = 'boxplot', sources_plot = NA, sample_column = 'unique_id') +
    facet_grid(~Priority16_bin)
  
  ggsave(filename, p, height = 5, width = 12)
}